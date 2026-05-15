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
import '../maintenance/maintenance_page.dart';
import '../maintenance/purchase_orders_page.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/archetypes/auxiliary_surfaces/searchable_picker.dart'
    as shared_picker;
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/confirm_dialog_key_handler.dart';
import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/utils/number_formatters.dart';
import 'inventory_page.dart';
import 'services_page.dart';
import 'services_shell.dart';
import 'warehouse_page.dart';
import 'weighings_page.dart';

const List<String> _kDirectoryAvailabilityOptions = <String>[
  'Disponible',
  'Bajo llamada',
  'Urgencia',
  'No disponible',
];

const double _kDirNameColW = 220;
const double _kDirAreaColW = 130;
const double _kDirSpecialtyColW = 170;
const double _kDirAvailabilityColW = 150;
const double _kDirContactColW = 160;
const double _kDirLocationColW = 170;
const double _kDirQuotesColW = 88;
const double _kDirVisitCostColW = 116;
const double _kDirWarrantyColW = 120;
const double _kDirCommentsColW = 230;
const double _kDirActionsColW = 124;

class OperationDirectoryPage extends StatefulWidget {
  const OperationDirectoryPage({super.key});

  @override
  State<OperationDirectoryPage> createState() => _OperationDirectoryPageState();
}

class _OperationDirectoryPageState extends State<OperationDirectoryPage> {
  final SupabaseClient _supa = Supabase.instance.client;
  final FocusNode _rowsFocusNode = FocusNode(
    debugLabel: 'operation-directory-rows',
  );
  final ScrollController _verticalScrollController = ScrollController();
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  final Map<String, Set<String>> _columnValueFilters = <String, Set<String>>{};
  final GlobalKey _rowsViewportKey = GlobalKey(
    debugLabel: 'directory-rows-viewport',
  );

  bool _loading = true;
  bool _saving = false;
  bool _runningAction = false;
  bool _schemaReady = true;
  String? _schemaMessage;
  List<Map<String, dynamic>> _contacts = <Map<String, dynamic>>[];
  List<String> _availableAreas = <String>[];
  List<String> _availableSpecialties = <String>[];
  String? _selectedContactId;
  String? _selectionAnchorContactId;
  final Set<String> _selectedContactIds = <String>{};
  Offset? _marqueeStartLocal;
  Offset? _marqueePointerLocal;
  Offset? _marqueeStartContent;
  Offset? _marqueeCurrentContent;
  bool _marqueeActive = false;
  bool _marqueeAdditive = false;
  Set<String> _marqueeBaseSelection = <String>{};
  Timer? _marqueeAutoScrollTimer;
  double _marqueeAutoScrollVelocity = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _marqueeAutoScrollTimer?.cancel();
    _rowsFocusNode.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await AuthAccess.resolveCurrentProfile();
      await _loadContacts();
      await _loadTaxonomyOptions();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadContacts() async {
    try {
      final rows = await _supa
          .from('operation_directory_contacts')
          .select('*')
          .order('active', ascending: false)
          .order('name');
      _contacts = (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map<String, dynamic>))
          .toList();
      await _enrichContactsWithTaxonomy();
      _selectedContactId = _sanitizeSelectedId(_selectedContactId, _contacts);
      _schemaReady = true;
      _schemaMessage = null;
    } on PostgrestException catch (e) {
      if (!_isMissingDirectorySchemaError(e)) rethrow;
      _contacts = <Map<String, dynamic>>[];
      _selectedContactId = null;
      _schemaReady = false;
      _schemaMessage =
          'Directorio Operación necesita la migración nueva en Supabase. Aplica `supabase db push` y vuelve a cargar.';
    }
    if (mounted) setState(() {});
  }

  Future<void> _enrichContactsWithTaxonomy() async {
    void applyLegacyFallback() {
      for (final row in _contacts) {
        final areaNames = _splitDirectoryTags(row['area']);
        final specialtyNames = _splitDirectoryTags(row['specialty']);
        row['area_names'] = areaNames;
        row['specialty_names'] = specialtyNames;
        if (areaNames.isNotEmpty) {
          row['area'] = areaNames.join(', ');
        }
        if (specialtyNames.isNotEmpty) {
          row['specialty'] = specialtyNames.join(', ');
        }
      }
    }

    try {
      final areaLinks = await _supa
          .from('operation_directory_contact_areas')
          .select('contact_id, area:operation_directory_areas(name)');
      final specialtyLinks = await _supa
          .from('operation_directory_contact_specialties')
          .select(
            'contact_id, specialty:operation_directory_specialties(name)',
          );
      final areaNamesByContact = <String, List<String>>{};
      final specialtyNamesByContact = <String, List<String>>{};

      for (final raw in areaLinks as List) {
        final row = Map<String, dynamic>.from(raw as Map<String, dynamic>);
        final contactId = (row['contact_id'] ?? '').toString();
        final area = Map<String, dynamic>.from(
          (row['area'] ?? const <String, dynamic>{}) as Map,
        );
        final name = (area['name'] ?? '').toString().trim();
        if (contactId.isEmpty || name.isEmpty) continue;
        areaNamesByContact.putIfAbsent(contactId, () => <String>[]).add(name);
      }

      for (final raw in specialtyLinks as List) {
        final row = Map<String, dynamic>.from(raw as Map<String, dynamic>);
        final contactId = (row['contact_id'] ?? '').toString();
        final specialty = Map<String, dynamic>.from(
          (row['specialty'] ?? const <String, dynamic>{}) as Map,
        );
        final name = (specialty['name'] ?? '').toString().trim();
        if (contactId.isEmpty || name.isEmpty) continue;
        specialtyNamesByContact
            .putIfAbsent(contactId, () => <String>[])
            .add(name);
      }

      for (final row in _contacts) {
        final contactId = (row['id'] ?? '').toString();
        final areaNames = _normalizeTagNames(
          areaNamesByContact[contactId] ?? _splitDirectoryTags(row['area']),
        );
        final specialtyNames = _normalizeTagNames(
          specialtyNamesByContact[contactId] ??
              _splitDirectoryTags(row['specialty']),
        );
        row['area_names'] = areaNames;
        row['specialty_names'] = specialtyNames;
        if (areaNames.isNotEmpty) {
          row['area'] = areaNames.join(', ');
        }
        if (specialtyNames.isNotEmpty) {
          row['specialty'] = specialtyNames.join(', ');
        }
      }
    } on PostgrestException catch (e) {
      if (!_isMissingDirectoryTaxonomyError(e)) rethrow;
      applyLegacyFallback();
    }
  }

  Future<void> _loadTaxonomyOptions() async {
    try {
      final areas = await _supa
          .from('operation_directory_areas')
          .select('name')
          .eq('active', true)
          .order('name');
      final specialties = await _supa
          .from('operation_directory_specialties')
          .select('name')
          .eq('active', true)
          .order('name');
      _availableAreas = _normalizeTagNames(
        (areas as List)
            .map((row) => (row as Map<String, dynamic>)['name'])
            .map((value) => (value ?? '').toString())
            .toList(),
      );
      _availableSpecialties = _normalizeTagNames(
        (specialties as List)
            .map((row) => (row as Map<String, dynamic>)['name'])
            .map((value) => (value ?? '').toString())
            .toList(),
      );
    } on PostgrestException catch (e) {
      if (!_isMissingDirectoryTaxonomyError(e)) rethrow;
      _availableAreas = _normalizeTagNames(
        _contacts.expand((row) => _tagsForContact(row, 'area')).toList(),
      );
      _availableSpecialties = _normalizeTagNames(
        _contacts.expand((row) => _tagsForContact(row, 'specialty')).toList(),
      );
    }
    if (mounted) setState(() {});
  }

  List<Map<String, dynamic>> get _filteredContacts {
    return _contacts.where((row) {
      for (final entry in _columnValueFilters.entries) {
        if (entry.value.isEmpty) continue;
        final values = _filterValuesForContact(row, entry.key);
        if (!values.any(entry.value.contains)) return false;
      }
      return true;
    }).toList();
  }

  bool get _hasActiveFilters => _columnValueFilters.isNotEmpty;

  void _clearFilters() {
    if (_columnValueFilters.isEmpty) return;
    setState(_columnValueFilters.clear);
  }

  String? _sanitizeSelectedId(
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

  GlobalKey _rowKeyFor(String id) =>
      _rowKeys.putIfAbsent(id, () => GlobalKey(debugLabel: id));

  Set<String> _currentSelectionIds() {
    if (_selectedContactIds.isNotEmpty) return {..._selectedContactIds};
    final id = _selectedContactId;
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

  double get _rowsScrollOffset => _verticalScrollController.hasClients
      ? _verticalScrollController.offset
      : 0;

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
    for (final row in _filteredContacts) {
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
      _selectedContactIds
        ..clear()
        ..addAll(next);
      if (next.isEmpty) {
        _selectedContactId = null;
        return;
      }
      if (_selectedContactId != null && next.contains(_selectedContactId)) {
        return;
      }
      for (final row in _filteredContacts) {
        final id = row['id']?.toString() ?? '';
        if (next.contains(id)) {
          _selectedContactId = id;
          _selectionAnchorContactId ??= id;
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
        !_verticalScrollController.hasClients) {
      _marqueeAutoScrollTimer?.cancel();
      _marqueeAutoScrollTimer = null;
      return;
    }
    final pos = _verticalScrollController.position;
    final next = (pos.pixels + _marqueeAutoScrollVelocity).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if (next == pos.pixels) return;
    _verticalScrollController.jumpTo(next);
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

  void _ensureVisible(String? id, {int? moveDelta}) {
    if (id == null) return;
    final rows = _filteredContacts;
    final index = rows.indexWhere((row) => row['id']?.toString() == id);
    if (index < 0) return;
    final alignmentPolicy = moveDelta == null
        ? ScrollPositionAlignmentPolicy.explicit
        : moveDelta < 0
        ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
        : ScrollPositionAlignmentPolicy.keepVisibleAtEnd;
    final rowContext = _rowKeys[id]?.currentContext;
    if (rowContext != null) {
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        alignmentPolicy: alignmentPolicy,
      );
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _rowKeys[id]?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        alignmentPolicy: alignmentPolicy,
      );
    });
  }

  void _selectContact(
    String? id, {
    bool requestFocus = true,
    bool ensureVisible = true,
    int? moveDelta,
    bool additive = false,
    bool additiveToggle = true,
    bool allowToggle = true,
  }) {
    if (!mounted) return;
    final normalized = id?.trim();
    setState(() {
      if (normalized == null || normalized.isEmpty) {
        _selectedContactId = null;
        _selectionAnchorContactId = null;
        _selectedContactIds.clear();
      } else if (additive) {
        final next = {..._currentSelectionIds()};
        if (additiveToggle && next.contains(normalized)) {
          next.remove(normalized);
        } else {
          next.add(normalized);
        }
        _selectedContactIds
          ..clear()
          ..addAll(next);
        if (next.isEmpty) {
          _selectedContactId = null;
          _selectionAnchorContactId = null;
        } else {
          _selectedContactId = normalized;
          _selectionAnchorContactId ??= normalized;
        }
      } else {
        if (allowToggle &&
            _selectedContactId == normalized &&
            _selectedContactIds.length <= 1) {
          _selectedContactId = null;
          _selectionAnchorContactId = null;
          _selectedContactIds.clear();
        } else {
          _selectedContactId = normalized;
          _selectionAnchorContactId = normalized;
          _selectedContactIds
            ..clear()
            ..add(normalized);
        }
      }
    });
    if (requestFocus) _rowsFocusNode.requestFocus();
    if (ensureVisible) _ensureVisible(normalized, moveDelta: moveDelta);
  }

  int _selectedIndexIn(List<Map<String, dynamic>> rows) {
    if (_selectedContactId == null) return rows.isEmpty ? -1 : 0;
    return rows.indexWhere(
      (row) => row['id']?.toString() == _selectedContactId,
    );
  }

  void _moveSelection(int delta) {
    final rows = _filteredContacts;
    if (rows.isEmpty) return;
    final currentIndex = _selectedIndexIn(rows);
    final safeIndex = currentIndex < 0 ? 0 : currentIndex;
    final nextIndex = (safeIndex + delta).clamp(0, rows.length - 1);
    _selectContact(
      rows[nextIndex]['id']?.toString(),
      requestFocus: true,
      moveDelta: delta,
    );
  }

  void _extendSelectionTo(String id, List<Map<String, dynamic>> rows) {
    if (rows.isEmpty || id.trim().isEmpty) return;
    final anchorId = (_selectionAnchorContactId?.isNotEmpty ?? false)
        ? _selectionAnchorContactId!
        : (_selectedContactId?.isNotEmpty ?? false)
        ? _selectedContactId!
        : id;
    final anchorIndex = rows.indexWhere(
      (row) => row['id']?.toString() == anchorId,
    );
    final currentIndex = rows.indexWhere((row) => row['id']?.toString() == id);
    if (anchorIndex < 0 || currentIndex < 0) {
      _selectContact(
        id,
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
      final rowId = rows[i]['id']?.toString() ?? '';
      if (rowId.isNotEmpty) ids.add(rowId);
    }
    setState(() {
      _selectedContactId = id;
      _selectionAnchorContactId = anchorId;
      _selectedContactIds
        ..clear()
        ..addAll(ids);
    });
    _rowsFocusNode.requestFocus();
  }

  Map<String, dynamic>? get _selectedContactRow {
    final selectedId = _selectedContactId;
    if (selectedId == null || selectedId.isEmpty) return null;
    for (final row in _filteredContacts) {
      if (row['id']?.toString() == selectedId) return row;
    }
    return null;
  }

  Future<void> _openSelectedActionsMenu() async {
    final row = _selectedContactRow;
    if (row == null) return;
    final rowContext = _rowKeys[_selectedContactId]?.currentContext;
    await _showActionsMenu(row, anchorContext: rowContext);
  }

  Future<bool> _showDirectoryConfirmDialog({
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

  Future<void> _toggleSelectedContact() async {
    final row = _selectedContactRow;
    if (row == null) return;
    final active = (row['active'] ?? true) == true;
    final ok = await _showDirectoryConfirmDialog(
      title: active ? 'Inactivar contacto' : 'Reactivar contacto',
      message: active
          ? 'Este contacto dejará de estar disponible para los flujos operativos.'
          : 'Este contacto volverá a estar disponible para Operación.',
      confirmText: active ? 'Inactivar' : 'Reactivar',
    );
    if (!ok) return;
    await _toggleActive(row);
  }

  Future<void> _deleteSelectedContactPermanently() async {
    final row = _selectedContactRow;
    if (row == null) return;
    await _deleteContactPermanently(row);
  }

  KeyEventResult _handleRowsKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final rows = _filteredContacts;
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
          _ensureVisible(nextId, moveDelta: 1);
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
          _ensureVisible(nextId, moveDelta: -1);
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
          .where((row) => row['id']?.toString() == _selectedContactId)
          .cast<Map<String, dynamic>?>()
          .firstWhere((row) => row != null, orElse: () => null);
      if (selected != null) {
        unawaited(_editContact(selected));
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
      if (HardwareKeyboard.instance.isShiftPressed) {
        unawaited(_deleteSelectedContactPermanently());
        return KeyEventResult.handled;
      }
      unawaited(_toggleSelectedContact());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && _selectedContactId != null) {
      _selectContact(null, requestFocus: true, ensureVisible: false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<String> _filterValuesForContact(
    Map<String, dynamic> row,
    String columnId,
  ) {
    switch (columnId) {
      case 'name':
        return _singleFilterValue(row['name']);
      case 'area':
        return _tagsForContact(row, 'area');
      case 'specialty':
        return _tagsForContact(row, 'specialty');
      case 'availability':
        return _singleFilterValue(row['availability']);
      case 'contact':
        return _singleFilterValue(row['contact']);
      case 'location':
        return _singleFilterValue(row['location']);
      case 'quotes':
        return <String>[_boolLabel(row['quotes'] == true)];
      case 'visit_cost':
        final value = _toDouble(row['visit_cost']);
        return <String>[value == null ? 'Sin costo' : _fmtMoney(value)];
      case 'warranty':
        return _singleFilterValue(row['warranty']);
      case 'active':
        return <String>[
          (row['active'] ?? true) == true ? 'Activo' : 'Inactivo',
        ];
      default:
        return const <String>[];
    }
  }

  List<String> _columnDistinctValues(String columnId, {String search = ''}) {
    final query = search.trim().toLowerCase();
    final values =
        _contacts
            .expand((row) => _filterValuesForContact(row, columnId))
            .where((value) => value.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (query.isEmpty) return values;
    return values
        .where((value) => value.toLowerCase().contains(query))
        .toList();
  }

  bool _hasColumnFilter(String columnId) =>
      (_columnValueFilters[columnId] ?? const <String>{}).isNotEmpty;

  Future<void> _openColumnFilterDialog(String columnId, String label) async {
    final initialSelected = {...(_columnValueFilters[columnId] ?? <String>{})};
    final scrollController = ScrollController();
    try {
      final result = await showDialog<_DirectoryFilterDialogResult>(
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
                  _DirectoryFilterDialogResult(selectedValues: localSelected),
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
                        decoration: _directoryFilterDialogDecoration(),
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
                                decoration: _directoryInputDecoration(
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
                                              return _DirectoryFilterValueTile(
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
                                        _directoryFilterOutlinedButtonStyle(),
                                    onPressed: () =>
                                        Navigator.pop(dialogContext),
                                    child: const Text('Cancelar'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    style:
                                        _directoryFilterOutlinedButtonStyle(),
                                    onPressed: () {
                                      Navigator.pop(
                                        dialogContext,
                                        const _DirectoryFilterDialogResult(
                                          selectedValues: <String>{},
                                        ),
                                      );
                                    },
                                    child: const Text('Limpiar'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    style: _directoryFilterFilledButtonStyle(),
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
        if (result.selectedValues.isEmpty) {
          _columnValueFilters.remove(columnId);
        } else {
          _columnValueFilters[columnId] = result.selectedValues;
        }
        _selectedContactId = _sanitizeSelectedId(
          _selectedContactId,
          _filteredContacts,
        );
      });
    } finally {
      scrollController.dispose();
    }
  }

  Future<void> _createContact() async {
    await _showContactDialog();
  }

  Future<void> _editContact(Map<String, dynamic> row) async {
    await _showContactDialog(initial: row);
  }

  Future<void> _showContactDialog({Map<String, dynamic>? initial}) async {
    final draft = await _showDirectoryDialog<_DirectoryDraft>(
      context: context,
      builder: (dialogContext) => _DirectoryContactDialog(
        initial: initial,
        availableAreas: _availableAreas,
        availableSpecialties: _availableSpecialties,
      ),
    );
    if (draft == null) return;
    if (draft.name.trim().isEmpty) {
      _toast('Escribe el nombre del contacto.');
      return;
    }
    await _saveContact(initial: initial, draft: draft);
  }

  Future<void> _saveContact({
    required Map<String, dynamic>? initial,
    required _DirectoryDraft draft,
  }) async {
    if (!_schemaReady) {
      _toast(_schemaMessage ?? 'Falta aplicar la migración.');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'name': draft.name.trim(),
        'area': _emptyAsNull(draft.areaSummary),
        'specialty': _emptyAsNull(draft.specialtySummary),
        'availability': _emptyAsNull(draft.availability),
        'contact': _emptyAsNull(draft.contact),
        'location': _emptyAsNull(draft.location),
        'quotes': draft.quotes,
        'visit_cost': draft.visitCost,
        'warranty': _emptyAsNull(draft.warranty),
        'comments': _emptyAsNull(draft.comments),
        'active': draft.active,
      };
      late final String contactId;
      if (initial == null) {
        final inserted = await _supa
            .from('operation_directory_contacts')
            .insert(payload)
            .select('id')
            .single();
        contactId = (inserted['id'] ?? '').toString();
      } else {
        await _supa
            .from('operation_directory_contacts')
            .update(payload)
            .eq('id', (initial['id'] ?? '').toString());
        contactId = (initial['id'] ?? '').toString();
      }
      await _syncContactTaxonomy(
        contactId: contactId,
        areaNames: draft.areaNames,
        specialtyNames: draft.specialtyNames,
      );
      await _loadContacts();
      await _loadTaxonomyOptions();
      _toast(initial == null ? 'Contacto creado' : 'Contacto actualizado');
    } catch (e) {
      _toast('No se pudo guardar el contacto: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> row) async {
    final id = (row['id'] ?? '').toString();
    if (id.isEmpty || _runningAction) return;
    setState(() => _runningAction = true);
    try {
      await _supa
          .from('operation_directory_contacts')
          .update({'active': !((row['active'] ?? true) == true)})
          .eq('id', id);
      await _loadContacts();
      _toast(
        (row['active'] ?? true) == true
            ? 'Contacto inactivado'
            : 'Contacto reactivado',
      );
    } catch (e) {
      _toast('No se pudo actualizar el contacto: $e');
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  Future<void> _deleteContactPermanently(Map<String, dynamic> row) async {
    final id = (row['id'] ?? '').toString();
    if (id.isEmpty || _runningAction) return;
    final ok = await _showDirectoryConfirmDialog(
      title: 'Eliminar contacto',
      message:
          'Este contacto se borrará permanentemente del directorio. Las órdenes antiguas conservarán su snapshot ya guardado.',
      confirmText: 'Eliminar',
    );
    if (!ok) return;
    setState(() => _runningAction = true);
    try {
      await _supa.from('operation_directory_contacts').delete().eq('id', id);
      await _loadContacts();
      await _loadTaxonomyOptions();
      _toast('Contacto eliminado permanentemente');
    } catch (e) {
      _toast('No se pudo eliminar el contacto: $e');
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  Future<void> _syncContactTaxonomy({
    required String contactId,
    required List<String> areaNames,
    required List<String> specialtyNames,
  }) async {
    if (contactId.isEmpty) return;
    try {
      final areaRows = await _upsertTaxonomyValues(
        table: 'operation_directory_areas',
        names: areaNames,
      );
      final specialtyRows = await _upsertTaxonomyValues(
        table: 'operation_directory_specialties',
        names: specialtyNames,
      );
      await _supa
          .from('operation_directory_contact_areas')
          .delete()
          .eq('contact_id', contactId);
      await _supa
          .from('operation_directory_contact_specialties')
          .delete()
          .eq('contact_id', contactId);
      if (areaRows.isNotEmpty) {
        await _supa
            .from('operation_directory_contact_areas')
            .insert(
              areaRows
                  .map(
                    (row) => <String, dynamic>{
                      'contact_id': contactId,
                      'area_id': row['id'],
                    },
                  )
                  .toList(),
            );
      }
      if (specialtyRows.isNotEmpty) {
        await _supa
            .from('operation_directory_contact_specialties')
            .insert(
              specialtyRows
                  .map(
                    (row) => <String, dynamic>{
                      'contact_id': contactId,
                      'specialty_id': row['id'],
                    },
                  )
                  .toList(),
            );
      }
    } on PostgrestException catch (e) {
      if (_isMissingDirectoryTaxonomyError(e)) return;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _upsertTaxonomyValues({
    required String table,
    required List<String> names,
  }) async {
    final normalized = _normalizeTagNames(names);
    if (normalized.isEmpty) return const <Map<String, dynamic>>[];
    final rows = await _supa
        .from(table)
        .upsert(
          normalized
              .map((name) => <String, dynamic>{'name': name, 'active': true})
              .toList(),
          onConflict: 'name',
        )
        .select('id, name');
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> _showActionsMenu(
    Map<String, dynamic> row, {
    Offset? globalPosition,
    BuildContext? anchorContext,
  }) async {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return;
    _selectContact(id, requestFocus: true, ensureVisible: false);
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
        const PopupMenuItem<String>(
          value: 'edit',
          child: _DirectoryActionMenuLabel(
            icon: Icons.edit_outlined,
            title: 'Editar',
            subtitle: 'Abrir la ficha del contacto',
          ),
        ),
        PopupMenuItem<String>(
          value: 'toggle',
          child: _DirectoryActionMenuLabel(
            icon: (row['active'] ?? true) == true
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            title: (row['active'] ?? true) == true ? 'Inactivar' : 'Reactivar',
            subtitle: (row['active'] ?? true) == true
                ? 'Ocultar del flujo operativo'
                : 'Volver a usar en Operación',
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: _DirectoryActionMenuLabel(
            icon: Icons.delete_forever_outlined,
            title: 'Eliminar permanentemente',
            subtitle: 'Borrar el contacto del directorio',
          ),
        ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        await _editContact(row);
        break;
      case 'toggle':
        await _toggleActive(row);
        break;
      case 'delete':
        await _deleteContactPermanently(row);
        break;
    }
  }

  int get _activeCount =>
      _contacts.where((row) => (row['active'] ?? true) == true).length;

  int get _quotesCount =>
      _contacts.where((row) => (row['quotes'] ?? true) == true).length;

  int get _areasCount => _contacts
      .expand((row) => _tagsForContact(row, 'area'))
      .where((value) => value.isNotEmpty)
      .toSet()
      .length;

  int get _specialtiesCount => _contacts
      .expand((row) => _tagsForContact(row, 'specialty'))
      .where((value) => value.isNotEmpty)
      .toSet()
      .length;

  String _fmtMoney(num value) => formatMoney(value);

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

  Future<void> _goToPurchaseOrders() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const PurchaseOrdersPage()));
  }

  Future<void> _goToWarehouse() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const WarehousePage()));
  }

  Widget _buildTopActionsBar() {
    final selected = _filteredContacts.where(
      (row) => row['id']?.toString() == _selectedContactId,
    );
    final selectedRow = selected.isEmpty ? null : selected.first;
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
                      style: _directoryActionFilledButtonStyle(),
                      onPressed: _saving || !_schemaReady
                          ? null
                          : _createContact,
                      icon: const Icon(Icons.add_box_rounded),
                      label: const Text('Nuevo contacto'),
                    ),
                    OutlinedButton.icon(
                      style: _directoryActionOutlinedButtonStyle(),
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
                    '${_filteredContacts.length} visibles · ${_contacts.length} totales',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _hasActiveFilters
                        ? '${_columnValueFilters.length} filtros activos'
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
                  if (selectedRow != null)
                    const Text(
                      'Enter/F2 edita · Space abre acciones · Delete cambia estado',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5A7287),
                      ),
                    ),
                  if (selectedRow != null)
                    Text(
                      'Selección: ${(selectedRow['name'] ?? '').toString()}',
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

  Widget _buildMetricStrip() {
    return Row(
      children: [
        _metricCard('Activos', '$_activeCount', Icons.badge_outlined),
        const SizedBox(width: 8),
        _metricCard('Cotizan', '$_quotesCount', Icons.request_quote_outlined),
        const SizedBox(width: 8),
        _metricCard('Áreas', '$_areasCount', Icons.apartment_rounded),
        const SizedBox(width: 8),
        _metricCard(
          'Especialidades',
          '$_specialtiesCount',
          Icons.handyman_outlined,
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

  Widget _buildDirectoryGrid() {
    final rows = _filteredContacts;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
      ),
      child: rows.isEmpty
          ? const Center(child: Text('No hay contactos con ese filtro.'))
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
                              _DirectoryHeaderCell(
                                label: 'NOMBRE',
                                width: _kDirNameColW,
                                active: _hasColumnFilter('name'),
                                onFilter: () =>
                                    _openColumnFilterDialog('name', 'NOMBRE'),
                              ),
                              const _DirectoryGridColumnDivider(),
                              _DirectoryHeaderCell(
                                label: 'AREA',
                                width: _kDirAreaColW,
                                active: _hasColumnFilter('area'),
                                onFilter: () =>
                                    _openColumnFilterDialog('area', 'AREA'),
                              ),
                              const _DirectoryGridColumnDivider(),
                              _DirectoryHeaderCell(
                                label: 'ESPECIALIDAD',
                                width: _kDirSpecialtyColW,
                                active: _hasColumnFilter('specialty'),
                                onFilter: () => _openColumnFilterDialog(
                                  'specialty',
                                  'ESPECIALIDAD',
                                ),
                              ),
                              const _DirectoryGridColumnDivider(),
                              _DirectoryHeaderCell(
                                label: 'DISPONIBILIDAD',
                                width: _kDirAvailabilityColW,
                                active: _hasColumnFilter('availability'),
                                onFilter: () => _openColumnFilterDialog(
                                  'availability',
                                  'DISPONIBILIDAD',
                                ),
                              ),
                              const _DirectoryGridColumnDivider(),
                              _DirectoryHeaderCell(
                                label: 'CONTACTO',
                                width: _kDirContactColW,
                                active: _hasColumnFilter('contact'),
                                onFilter: () => _openColumnFilterDialog(
                                  'contact',
                                  'CONTACTO',
                                ),
                              ),
                              const _DirectoryGridColumnDivider(),
                              _DirectoryHeaderCell(
                                label: 'UBICACION',
                                width: _kDirLocationColW,
                                active: _hasColumnFilter('location'),
                                onFilter: () => _openColumnFilterDialog(
                                  'location',
                                  'UBICACION',
                                ),
                              ),
                              const _DirectoryGridColumnDivider(),
                              _DirectoryHeaderCell(
                                label: 'COTIZA',
                                width: _kDirQuotesColW,
                                active: _hasColumnFilter('quotes'),
                                onFilter: () =>
                                    _openColumnFilterDialog('quotes', 'COTIZA'),
                              ),
                              const _DirectoryGridColumnDivider(),
                              _DirectoryHeaderCell(
                                label: 'COSTO VISITA',
                                width: _kDirVisitCostColW,
                                active: _hasColumnFilter('visit_cost'),
                                onFilter: () => _openColumnFilterDialog(
                                  'visit_cost',
                                  'COSTO VISITA',
                                ),
                              ),
                              const _DirectoryGridColumnDivider(),
                              _DirectoryHeaderCell(
                                label: 'GARANTIA',
                                width: _kDirWarrantyColW,
                                active: _hasColumnFilter('warranty'),
                                onFilter: () => _openColumnFilterDialog(
                                  'warranty',
                                  'GARANTIA',
                                ),
                              ),
                              const _DirectoryGridColumnDivider(),
                              _DirectoryHeaderCell(
                                label: 'COMENTARIO',
                                width: _kDirCommentsColW,
                                active: false,
                                onFilter: () {},
                              ),
                              const _DirectoryGridColumnDivider(),
                              _DirectoryHeaderCell(
                                label: 'ACCIONES',
                                width: _kDirActionsColW,
                                active: _hasColumnFilter('active'),
                                onFilter: () =>
                                    _openColumnFilterDialog('active', 'ACTIVO'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Scrollbar(
                        controller: _verticalScrollController,
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
                                      controller: _verticalScrollController,
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      itemCount: rows.length,
                                      itemBuilder: (context, index) {
                                        final row = rows[index];
                                        final id = row['id']?.toString();
                                        final isSelected =
                                            id != null &&
                                            _currentSelectionIds().contains(id);
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            bottom: index == rows.length - 1
                                                ? 0
                                                : 6,
                                          ),
                                          child: _DirectoryRowCard(
                                            key: id == null
                                                ? ValueKey(index)
                                                : _rowKeyFor(id),
                                            row: row,
                                            selected: isSelected,
                                            onTap: () {
                                              final normalized =
                                                  id?.trim() ?? '';
                                              if (normalized.isEmpty) return;
                                              if (_isShiftPressed()) {
                                                _extendSelectionTo(
                                                  normalized,
                                                  rows,
                                                );
                                                return;
                                              }
                                              _selectContact(
                                                normalized,
                                                requestFocus: true,
                                                ensureVisible: false,
                                                additive: _isCtrlOrCmdPressed(),
                                                additiveToggle: true,
                                                allowToggle: false,
                                              );
                                            },
                                            onDoubleTap: () =>
                                                _editContact(row),
                                            onSecondaryTapDown: (details) {
                                              final normalized =
                                                  id?.trim() ?? '';
                                              if (normalized.isNotEmpty &&
                                                  !_currentSelectionIds()
                                                      .contains(normalized)) {
                                                _selectContact(
                                                  normalized,
                                                  requestFocus: true,
                                                  ensureVisible: false,
                                                  allowToggle: false,
                                                );
                                              }
                                              unawaited(
                                                _showActionsMenu(
                                                  row,
                                                  globalPosition:
                                                      details.globalPosition,
                                                ),
                                              );
                                            },
                                            onOpenActions: (buttonContext) =>
                                                _showActionsMenu(
                                                  row,
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
                                              _DirectoryMarqueeSelectionPainter(
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

  @override
  Widget build(BuildContext context) {
    return ServicesShell(
      headerTitle: 'Directorio Operación',
      activeOverlayModule: ServicesOverlayNavModule.directorioOperacion,
      onLogout: _logout,
      onGoToGeneralDashboard: _goToGeneralDashboard,
      onGoToOperacion: _goToDashboard,
      onGoToEntriesAndOutputs: _goToEntriesAndOutputs,
      onGoToProduction: _goToProduction,
      onGoToInventory: _goToInventory,
      onGoToServices: _goToServices,
      onGoToWeighings: _goToWeighings,
      onGoToMaintenance: _goToMaintenance,
      onGoToPurchaseOrders: _goToPurchaseOrders,
      onGoToWarehouse: _goToWarehouse,
      onGoToOperationDirectory: () async {},
      topContent: OperationalGlassToolbarPanel(child: _buildTopActionsBar()),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_schemaReady && _schemaMessage != null) ...[
                  _DirectorySchemaWarningCard(message: _schemaMessage!),
                  const SizedBox(height: 12),
                ],
                _buildMetricStrip(),
                const SizedBox(height: 12),
                Expanded(child: _buildDirectoryGrid()),
              ],
            ),
    );
  }
}

Future<T?> _showDirectoryDialog<T>({
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

class _DirectoryFilterDialogResult {
  final Set<String> selectedValues;
  const _DirectoryFilterDialogResult({required this.selectedValues});
}

class _DirectoryDraft {
  final String name;
  final List<String> areaNames;
  final List<String> specialtyNames;
  final String availability;
  final String contact;
  final String location;
  final bool quotes;
  final double? visitCost;
  final String warranty;
  final String comments;
  final bool active;

  const _DirectoryDraft({
    required this.name,
    required this.areaNames,
    required this.specialtyNames,
    required this.availability,
    required this.contact,
    required this.location,
    required this.quotes,
    required this.visitCost,
    required this.warranty,
    required this.comments,
    required this.active,
  });

  String get areaSummary => areaNames.join(', ');

  String get specialtySummary => specialtyNames.join(', ');
}

class _DirectoryHeaderCell extends StatelessWidget {
  final String label;
  final double width;
  final bool active;
  final VoidCallback onFilter;

  const _DirectoryHeaderCell({
    required this.label,
    required this.width,
    required this.active,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _KeyboardGridAction(
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
      ),
    );
  }
}

class _KeyboardGridAction extends StatefulWidget {
  final VoidCallback onActivate;
  final Widget Function(BuildContext context, bool focused) builder;

  const _KeyboardGridAction({required this.onActivate, required this.builder});

  @override
  State<_KeyboardGridAction> createState() => _KeyboardGridActionState();
}

class _KeyboardGridActionState extends State<_KeyboardGridAction> {
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

class _DirectoryActionMenuLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _DirectoryActionMenuLabel({
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

class _DirectoryRowCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  final Future<void> Function(BuildContext buttonContext) onOpenActions;

  const _DirectoryRowCard({
    super.key,
    required this.row,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
    required this.onSecondaryTapDown,
    required this.onOpenActions,
  });

  @override
  Widget build(BuildContext context) {
    final active = (row['active'] ?? true) == true;
    return Card(
      elevation: selected ? 2.8 : 0.9,
      shadowColor: const Color(
        0xFF17324A,
      ).withValues(alpha: selected ? 0.18 : 0.08),
      color: selected
          ? const Color(0xFFD9ECFA)
          : Colors.white.withValues(alpha: 0.86),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? const Color(0xFF3C8DCC).withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        mouseCursor: SystemMouseCursors.click,
        hoverColor: const Color(0xFFEFF7FD),
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
                  width: _kDirNameColW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (row['name'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF17324A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        active ? 'Activo' : 'Inactivo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: active
                              ? const Color(0xFF0D5C46)
                              : const Color(0xFF8A1F1F),
                        ),
                      ),
                    ],
                  ),
                ),
                const _DirectoryGridColumnDivider(),
                _DirectoryValueCell(width: _kDirAreaColW, value: row['area']),
                const _DirectoryGridColumnDivider(),
                _DirectoryValueCell(
                  width: _kDirSpecialtyColW,
                  value: row['specialty'],
                ),
                const _DirectoryGridColumnDivider(),
                _DirectoryValueCell(
                  width: _kDirAvailabilityColW,
                  value: row['availability'],
                ),
                const _DirectoryGridColumnDivider(),
                _DirectoryValueCell(
                  width: _kDirContactColW,
                  value: row['contact'],
                ),
                const _DirectoryGridColumnDivider(),
                _DirectoryValueCell(
                  width: _kDirLocationColW,
                  value: row['location'],
                ),
                const _DirectoryGridColumnDivider(),
                SizedBox(
                  width: _kDirQuotesColW,
                  child: Text(
                    _boolLabel(row['quotes'] == true),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const _DirectoryGridColumnDivider(),
                SizedBox(
                  width: _kDirVisitCostColW,
                  child: Text(
                    _toDouble(row['visit_cost']) == null
                        ? 'Sin costo'
                        : formatMoney(_toDouble(row['visit_cost'])!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const _DirectoryGridColumnDivider(),
                _DirectoryValueCell(
                  width: _kDirWarrantyColW,
                  value: row['warranty'],
                ),
                const _DirectoryGridColumnDivider(),
                _DirectoryValueCell(
                  width: _kDirCommentsColW,
                  value: row['comments'],
                ),
                const _DirectoryGridColumnDivider(),
                AnchoredActionSlot(
                  width: _kDirActionsColW,
                  trailingWidth: _kDirActionsColW,
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

class _DirectoryMarqueeSelectionPainter extends CustomPainter {
  final Rect rect;

  const _DirectoryMarqueeSelectionPainter({required this.rect});

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
  bool shouldRepaint(covariant _DirectoryMarqueeSelectionPainter oldDelegate) =>
      oldDelegate.rect != rect;
}

class _DirectoryGridColumnDivider extends StatelessWidget {
  const _DirectoryGridColumnDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(width: 1, height: 34, color: const Color(0xFFBFD5E3)),
    );
  }
}

class _DirectoryValueCell extends StatelessWidget {
  final double width;
  final Object? value;

  const _DirectoryValueCell({required this.width, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        (value ?? '').toString().trim().isEmpty
            ? '-'
            : (value ?? '').toString(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DirectoryPickerOption<T> {
  final T value;
  final String label;
  final String? subtitle;

  const _DirectoryPickerOption({
    required this.value,
    required this.label,
    this.subtitle,
  });
}

class _DirectorySelectField<T> extends StatelessWidget {
  final String label;
  final T value;
  final String displayValue;
  final List<_DirectoryPickerOption<T>> options;
  final ValueChanged<T> onChanged;

  const _DirectorySelectField({
    required this.label,
    required this.value,
    required this.displayValue,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Future<void> openPicker() async {
      final picked = await _showDirectorySearchablePickerDialog<T>(
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
          decoration: _directoryInputDecoration(labelText: label),
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

class _DirectoryMultiSelectField extends StatelessWidget {
  final String label;
  final List<String> values;
  final List<String> options;
  final ValueChanged<List<String>> onChanged;
  final Future<bool> Function(String value)? onDeleteOption;

  const _DirectoryMultiSelectField({
    required this.label,
    required this.values,
    required this.options,
    required this.onChanged,
    this.onDeleteOption,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = values.isEmpty
        ? 'Seleccionar o agregar'
        : values.join(', ');
    Future<void> openPicker() async {
      final picked = await _showDirectoryTagPickerDialog(
        context: context,
        title: label,
        initialValues: values,
        options: options,
        onDeleteOption: onDeleteOption,
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
          decoration: _directoryInputDecoration(labelText: label),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayValue,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: values.isEmpty
                        ? const Color(0xFF5A7287)
                        : const Color(0xFF17324A),
                  ),
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

class _DirectoryFilterValueTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final String? deleteTooltip;

  const _DirectoryFilterValueTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onDelete,
    this.deleteTooltip,
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
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Tooltip(
                        message: deleteTooltip ?? 'Eliminar opción',
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Color(0xFF8A1F1F),
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
    );
  }
}

Future<T?> _showDirectorySearchablePickerDialog<T>({
  required BuildContext context,
  required String title,
  required T selectedValue,
  required List<_DirectoryPickerOption<T>> options,
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

Future<List<String>?> _showDirectoryTagPickerDialog({
  required BuildContext context,
  required String title,
  required List<String> initialValues,
  required List<String> options,
  Future<bool> Function(String value)? onDeleteOption,
}) {
  return _showDirectoryDialog<List<String>>(
    context: context,
    builder: (dialogContext) => _DirectoryTagPickerDialog(
      title: title,
      initialValues: initialValues,
      options: options,
      onDeleteOption: onDeleteOption,
    ),
  );
}

class _DirectoryTagPickerDialog extends StatefulWidget {
  final String title;
  final List<String> initialValues;
  final List<String> options;
  final Future<bool> Function(String value)? onDeleteOption;

  const _DirectoryTagPickerDialog({
    required this.title,
    required this.initialValues,
    required this.options,
    this.onDeleteOption,
  });

  @override
  State<_DirectoryTagPickerDialog> createState() =>
      _DirectoryTagPickerDialogState();
}

class _DirectoryTagPickerDialogState extends State<_DirectoryTagPickerDialog> {
  late final TextEditingController _searchC;
  late final Set<String> _selected;
  late final List<String> _options;
  final ScrollController _optionsScrollController = ScrollController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchC = TextEditingController();
    _selected = {..._normalizeTagNames(widget.initialValues)};
    _options = _normalizeTagNames(widget.options);
    for (final value in _selected) {
      if (_options.any(
        (option) => option.toLowerCase() == value.toLowerCase(),
      )) {
        continue;
      }
      _options.add(value);
    }
    _options.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  @override
  void dispose() {
    _searchC.dispose();
    _optionsScrollController.dispose();
    super.dispose();
  }

  bool get _canAddCurrentQuery {
    final normalized = _query.trim();
    if (normalized.isEmpty) return false;
    return !_options.any(
      (option) => option.toLowerCase() == normalized.toLowerCase(),
    );
  }

  List<String> get _visibleOptions {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _options;
    return _options
        .where((option) => option.toLowerCase().contains(query))
        .toList(growable: false);
  }

  void _toggleValue(String value) {
    setState(() {
      if (_selected.contains(value)) {
        _selected.remove(value);
      } else {
        _selected.add(value);
      }
    });
  }

  void _addCurrentQuery() {
    final normalized = _query.trim();
    if (normalized.isEmpty) return;
    setState(() {
      _options.add(normalized);
      _options.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _selected.add(normalized);
      _query = '';
      _searchC.clear();
    });
  }

  Future<void> _deleteOption(String value) async {
    final deleteRemotely = widget.onDeleteOption;
    if (deleteRemotely != null) {
      final deleted = await deleteRemotely(value);
      if (!deleted || !mounted) return;
    }
    setState(() {
      _options.removeWhere(
        (option) => option.toLowerCase() == value.toLowerCase(),
      );
      _selected.removeWhere(
        (option) => option.toLowerCase() == value.toLowerCase(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleOptions = _visibleOptions;
    final selectedValues = _normalizeTagNames(_selected);
    return ContractDialogShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF17324A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${selectedValues.length} sel.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF35526A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchC,
                onChanged: (value) => setState(() => _query = value),
                decoration: _directoryInputDecoration(
                  labelText: 'Buscar o agregar',
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              if (_canAddCurrentQuery) ...[
                const SizedBox(height: 8),
                _DirectoryFilterValueTile(
                  label: 'Agregar "${_query.trim()}"',
                  selected: true,
                  onTap: _addCurrentQuery,
                ),
              ],
              if (selectedValues.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (
                          var index = 0;
                          index < selectedValues.length;
                          index++
                        )
                          Padding(
                            padding: EdgeInsets.only(
                              right: index == selectedValues.length - 1 ? 0 : 8,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE7F1F8),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(
                                    0xFFB7D7D2,
                                  ).withValues(alpha: 0.9),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    selectedValues[index],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF17324A),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: () =>
                                        _toggleValue(selectedValues[index]),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: Color(0xFF35526A),
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
              ],
              const SizedBox(height: 10),
              Expanded(
                child: visibleOptions.isEmpty
                    ? const Center(child: Text('Sin coincidencias'))
                    : ListView.builder(
                        controller: _optionsScrollController,
                        itemCount: visibleOptions.length,
                        itemBuilder: (context, index) {
                          final value = visibleOptions[index];
                          final selected = _selected.contains(value);
                          return _DirectoryFilterValueTile(
                            label: value,
                            selected: selected,
                            onTap: () => _toggleValue(value),
                            onDelete: () => _deleteOption(value),
                            deleteTooltip: 'Eliminar "$value"',
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: _directoryActionOutlinedButtonStyle(),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    style: _directoryActionFilledButtonStyle(),
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(_normalizeTagNames(_selected)),
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

class _DirectoryContactDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final List<String> availableAreas;
  final List<String> availableSpecialties;

  const _DirectoryContactDialog({
    this.initial,
    required this.availableAreas,
    required this.availableSpecialties,
  });

  @override
  State<_DirectoryContactDialog> createState() =>
      _DirectoryContactDialogState();
}

class _DirectoryContactDialogState extends State<_DirectoryContactDialog> {
  late final TextEditingController _nameC;
  late final TextEditingController _contactC;
  late final TextEditingController _locationC;
  late final TextEditingController _visitCostC;
  late final TextEditingController _warrantyC;
  late final TextEditingController _commentsC;
  late String _availability;
  late bool _quotes;
  late bool _active;
  late List<String> _selectedAreas;
  late List<String> _selectedSpecialties;
  late List<String> _areaOptions;
  late List<String> _specialtyOptions;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(
      text: (widget.initial?['name'] ?? '').toString(),
    );
    _contactC = TextEditingController(
      text: (widget.initial?['contact'] ?? '').toString(),
    );
    _locationC = TextEditingController(
      text: (widget.initial?['location'] ?? '').toString(),
    );
    _visitCostC = TextEditingController(
      text: (widget.initial?['visit_cost'] ?? '').toString(),
    );
    _warrantyC = TextEditingController(
      text: (widget.initial?['warranty'] ?? '').toString(),
    );
    _commentsC = TextEditingController(
      text: (widget.initial?['comments'] ?? '').toString(),
    );
    final availability = (widget.initial?['availability'] ?? 'Disponible')
        .toString();
    _availability = _kDirectoryAvailabilityOptions.contains(availability)
        ? availability
        : _kDirectoryAvailabilityOptions.first;
    _quotes = (widget.initial?['quotes'] ?? true) == true;
    _active = (widget.initial?['active'] ?? true) == true;
    _selectedAreas = _normalizeTagNames(
      _coerceTagList(widget.initial?['area_names'], widget.initial?['area']),
    );
    _selectedSpecialties = _normalizeTagNames(
      _coerceTagList(
        widget.initial?['specialty_names'],
        widget.initial?['specialty'],
      ),
    );
    _areaOptions = _normalizeTagNames(widget.availableAreas);
    _specialtyOptions = _normalizeTagNames(widget.availableSpecialties);
  }

  @override
  void dispose() {
    _nameC.dispose();
    _contactC.dispose();
    _locationC.dispose();
    _visitCostC.dispose();
    _warrantyC.dispose();
    _commentsC.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      _DirectoryDraft(
        name: _nameC.text.trim(),
        areaNames: _selectedAreas,
        specialtyNames: _selectedSpecialties,
        availability: _availability,
        contact: _contactC.text.trim(),
        location: _locationC.text.trim(),
        quotes: _quotes,
        visitCost: _toDouble(_visitCostC.text),
        warranty: _warrantyC.text.trim(),
        comments: _commentsC.text.trim(),
        active: _active,
      ),
    );
  }

  Future<bool> _deleteTaxonomyOption({
    required String table,
    required String value,
    required bool isArea,
  }) async {
    final normalized = value.trim();
    if (normalized.isEmpty) return false;
    final messenger = ScaffoldMessenger.of(context);
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
                    const Text(
                      'Eliminar opción',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF17324A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Se eliminará "$normalized" del catálogo de ${isArea ? 'áreas' : 'especialidades'} y también se quitará de los contactos que la tengan asignada.',
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
                          child: const Text('Eliminar'),
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
    if (confirmed != true || !mounted) return false;
    try {
      await Supabase.instance.client
          .from(table)
          .delete()
          .eq('name', normalized);
      setState(() {
        if (isArea) {
          _areaOptions.removeWhere(
            (option) => option.toLowerCase() == normalized.toLowerCase(),
          );
          _selectedAreas.removeWhere(
            (option) => option.toLowerCase() == normalized.toLowerCase(),
          );
        } else {
          _specialtyOptions.removeWhere(
            (option) => option.toLowerCase() == normalized.toLowerCase(),
          );
          _selectedSpecialties.removeWhere(
            (option) => option.toLowerCase() == normalized.toLowerCase(),
          );
        }
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Opción eliminada: $normalized')),
      );
      return true;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo eliminar "$normalized": $e')),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initial == null
                    ? 'Nuevo contacto del directorio'
                    : 'Editar contacto del directorio',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF17324A),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DirectoryDialogSection(
                        title: 'Datos base',
                        child: Column(
                          children: [
                            TextField(
                              controller: _nameC,
                              decoration: _directoryInputDecoration(
                                labelText: 'Nombre',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: 220,
                                  child: _DirectoryMultiSelectField(
                                    label: 'Área',
                                    values: _selectedAreas,
                                    options: _areaOptions,
                                    onChanged: (values) {
                                      setState(() => _selectedAreas = values);
                                    },
                                    onDeleteOption: (value) =>
                                        _deleteTaxonomyOption(
                                          table: 'operation_directory_areas',
                                          value: value,
                                          isArea: true,
                                        ),
                                  ),
                                ),
                                SizedBox(
                                  width: 280,
                                  child: _DirectoryMultiSelectField(
                                    label: 'Especialidad',
                                    values: _selectedSpecialties,
                                    options: _specialtyOptions,
                                    onChanged: (values) {
                                      setState(
                                        () => _selectedSpecialties = values,
                                      );
                                    },
                                    onDeleteOption: (value) =>
                                        _deleteTaxonomyOption(
                                          table:
                                              'operation_directory_specialties',
                                          value: value,
                                          isArea: false,
                                        ),
                                  ),
                                ),
                                SizedBox(
                                  width: 220,
                                  child: _DirectorySelectField<String>(
                                    label: 'Disponibilidad',
                                    value: _availability,
                                    displayValue: _availability,
                                    options: _kDirectoryAvailabilityOptions
                                        .map(
                                          (value) => _DirectoryPickerOption(
                                            value: value,
                                            label: value,
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() => _availability = value);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _DirectoryDialogSection(
                        title: 'Contacto y operación',
                        child: Column(
                          children: [
                            TextField(
                              controller: _contactC,
                              decoration: _directoryInputDecoration(
                                labelText: 'Contacto',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _locationC,
                              decoration: _directoryInputDecoration(
                                labelText: 'Ubicación',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: 180,
                                  child: _DirectorySelectField<bool>(
                                    label: 'Cotiza',
                                    value: _quotes,
                                    displayValue: _quotes
                                        ? 'Sí cotiza'
                                        : 'No cotiza',
                                    options: const [
                                      _DirectoryPickerOption(
                                        value: true,
                                        label: 'Sí cotiza',
                                      ),
                                      _DirectoryPickerOption(
                                        value: false,
                                        label: 'No cotiza',
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() => _quotes = value);
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 180,
                                  child: TextField(
                                    controller: _visitCostC,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: _directoryInputDecoration(
                                      labelText: 'Costo por visita',
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 220,
                                  child: TextField(
                                    controller: _warrantyC,
                                    decoration: _directoryInputDecoration(
                                      labelText: 'Garantía',
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 180,
                                  child: _DirectorySelectField<bool>(
                                    label: 'Estatus',
                                    value: _active,
                                    displayValue: _active
                                        ? 'Activo'
                                        : 'Inactivo',
                                    options: const [
                                      _DirectoryPickerOption(
                                        value: true,
                                        label: 'Activo',
                                      ),
                                      _DirectoryPickerOption(
                                        value: false,
                                        label: 'Inactivo',
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() => _active = value);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _commentsC,
                              minLines: 3,
                              maxLines: 5,
                              decoration: _directoryInputDecoration(
                                labelText: 'Comentario',
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
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _submit,
                    child: Text(
                      widget.initial == null ? 'Crear contacto' : 'Guardar',
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

class _DirectoryDialogSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DirectoryDialogSection({required this.title, required this.child});

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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF17324A),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DirectorySchemaWarningCard extends StatelessWidget {
  final String message;

  const _DirectorySchemaWarningCard({required this.message});

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

BoxDecoration _directoryFilterDialogDecoration() {
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

ButtonStyle _directoryFilterOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF2A4B49),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
    backgroundColor: Colors.white.withValues(alpha: 0.6),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontWeight: FontWeight.w700),
  );
}

ButtonStyle _directoryFilterFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF6C8E87),
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

ButtonStyle _directoryActionFilledButtonStyle() {
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

ButtonStyle _directoryActionOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF17324A),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
    backgroundColor: Colors.white.withValues(alpha: 0.52),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

InputDecoration _directoryInputDecoration({
  String? labelText,
  Widget? prefixIcon,
}) {
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

String _boolLabel(bool value) => value ? 'Sí' : 'No';

bool _isMissingDirectorySchemaError(PostgrestException error) {
  return error.message.toLowerCase().contains('operation_directory_contacts');
}

bool _isMissingDirectoryTaxonomyError(PostgrestException error) {
  final message = error.message.toLowerCase();
  return message.contains('operation_directory_areas') ||
      message.contains('operation_directory_specialties') ||
      message.contains('operation_directory_contact_areas') ||
      message.contains('operation_directory_contact_specialties');
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

List<String> _splitDirectoryTags(dynamic raw) {
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty) return const <String>[];
  return _normalizeTagNames(text.split(RegExp(r'[,;/\n\r]+')));
}

List<String> _normalizeTagNames(Iterable<String> values) {
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

List<String> _singleFilterValue(dynamic raw) {
  final value = (raw ?? '').toString().trim();
  return value.isEmpty ? const <String>[] : <String>[value];
}

List<String> _tagsForContact(Map<String, dynamic> row, String field) {
  final tagKey = '${field}_names';
  final fromNames = _coerceTagList(row[tagKey], row[field]);
  return _normalizeTagNames(fromNames);
}

List<String> _coerceTagList(dynamic raw, dynamic fallback) {
  if (raw is List) {
    return raw.map((value) => (value ?? '').toString()).toList();
  }
  return _splitDirectoryTags(fallback);
}
