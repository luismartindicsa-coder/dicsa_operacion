import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_navigation.dart';
import '../shared/app_shell.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/ui_contract_core/dialogs/contract_popup_surface.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import '../shared/utils/number_formatters.dart';
import 'menudeo_catalog_page.dart';
import 'menudeo_dashboard_page.dart';
import 'menudeo_deposits_expenses_page.dart';
import 'menudeo_filter_widgets.dart';
import 'menudeo_header_brand.dart';
import 'menudeo_session_confirm_dialog.dart';
import 'menudeo_sales_page.dart';
import 'menudeo_tickets_page.dart';
import 'menudeo_theme.dart';

class MenudeoPriceAdjustmentsPage extends StatefulWidget {
  final bool instantOpen;

  const MenudeoPriceAdjustmentsPage({super.key, this.instantOpen = false});

  @override
  State<MenudeoPriceAdjustmentsPage> createState() =>
      _MenudeoPriceAdjustmentsPageState();
}

class _MenudeoPriceAdjustmentsPageState
    extends State<MenudeoPriceAdjustmentsPage> {
  final SupabaseClient _supa = Supabase.instance.client;
  final TextEditingController _adjustmentValueC = TextEditingController();
  final TextEditingController _reasonC = TextEditingController();
  final ScrollController _rowsScrollC = ScrollController();
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};

  bool _menuOpen = false;
  bool _insightsOpen = false;
  bool _insightsTriggerHovered = false;
  bool _loading = true;
  bool _applying = false;
  int _currentPage = 0;
  int _pageSize = 40;
  String? _error;
  String? _selectedKind;
  String? _selectedGroup;
  String? _selectedCounterparty;
  String? _selectedMaterial;
  String _adjustmentMode = 'delta_amount';
  int _deltaDirection = 1;
  String? _activePriceId;
  String? _selectionAnchorPriceId;
  bool _dragSelecting = false;
  String? _dragAnchorPriceId;
  final Set<String> _selectedPriceIds = <String>{};
  List<Map<String, dynamic>> _priceRows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _historyRows = <Map<String, dynamic>>[];
  String _historyMovementFilter = 'todos';
  String? _historyCounterpartyFilter;
  String? _historyMaterialFilter;
  DateTimeRange? _historyDateRange;

  @override
  void initState() {
    super.initState();
    for (final controller in [_adjustmentValueC, _reasonC]) {
      controller.addListener(() {
        if (mounted) setState(() {});
      });
    }
    unawaited(_loadRows());
  }

  @override
  void dispose() {
    _adjustmentValueC.dispose();
    _reasonC.dispose();
    _rowsScrollC.dispose();
    super.dispose();
  }

  Future<void> _loadRows() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait([
        _supa
            .from('vw_men_price_audit_catalog')
            .select()
            .order('counterparty_name')
            .order('material_label_snapshot'),
        _supa
            .from('vw_men_price_adjustment_history')
            .select()
            .order('created_at', ascending: false)
            .limit(1500),
      ]);
      if (!mounted) return;
      final catalogData = responses[0] as List;
      final historyData = responses[1] as List;
      setState(() {
        _priceRows = catalogData
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
        _historyRows = historyData
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
        _selectedPriceIds.removeWhere(
          (id) => !_priceRows.any(
            (row) => (row['price_id'] ?? '').toString() == id,
          ),
        );
        if (_activePriceId != null &&
            !_priceRows.any(
              (row) => (row['price_id'] ?? '').toString() == _activePriceId,
            )) {
          _activePriceId = null;
          _selectionAnchorPriceId = null;
        }
        _loading = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _directionLabel(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'purchase':
        return 'COMPRA';
      case 'sale':
        return 'VENTA';
      default:
        return raw.trim().toUpperCase();
    }
  }

  String _sanitizePathSegment(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return 'SIN NOMBRE';
    return cleaned;
  }

  String _rowDirectionLabel(Map<String, dynamic> row) {
    final rawDirection = (row['direction'] ?? '').toString().trim();
    if (rawDirection.isNotEmpty) {
      return _directionLabel(rawDirection);
    }
    switch ((row['kind'] ?? '').toString().trim().toLowerCase()) {
      case 'supplier':
        return 'COMPRA';
      case 'customer':
        return 'VENTA';
      default:
        return '';
    }
  }

  bool _matchesDirectionScope(
    Map<String, dynamic> row,
    String? selectedDirection,
  ) {
    if (selectedDirection == null) return true;
    return _rowDirectionLabel(row) == selectedDirection;
  }

  List<Map<String, dynamic>> get _filteredRows {
    return _priceRows
        .where((row) {
          final group = (row['group_code'] ?? '').toString().toUpperCase();
          final counterparty = (row['counterparty_name'] ?? '')
              .toString()
              .toUpperCase();
          final material = (row['material_label_snapshot'] ?? '')
              .toString()
              .toUpperCase();
          if (!_matchesDirectionScope(row, _selectedKind)) return false;
          if (_selectedGroup != null && _selectedGroup != group) return false;
          if (_selectedCounterparty != null &&
              _selectedCounterparty != counterparty) {
            return false;
          }
          if (_selectedMaterial != null && _selectedMaterial != material) {
            return false;
          }
          return (row['price_active'] ?? true) == true;
        })
        .toList(growable: false);
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

  List<Map<String, dynamic>> _pageRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const <Map<String, dynamic>>[];
    final currentPage = _effectiveCurrentPageFor(rows.length);
    final start = currentPage * _pageSize;
    final end = math.min(start + _pageSize, rows.length);
    return rows.sublist(start, end);
  }

  List<Map<String, dynamic>> get _visiblePriceRows => _pageRows(_filteredRows);

  List<String> get _availableKinds {
    final kinds =
        _priceRows
            .map(_rowDirectionLabel)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return kinds;
  }

  List<String> get _availableGroups {
    final groups =
        _priceRows
            .where((row) {
              if (!_matchesDirectionScope(row, _selectedKind)) {
                return false;
              }
              return (row['price_active'] ?? true) == true;
            })
            .map((row) => (row['group_code'] ?? '').toString().toUpperCase())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return groups;
  }

  List<String> get _availableCounterparties {
    final values =
        _priceRows
            .where((row) {
              final group = (row['group_code'] ?? '').toString().toUpperCase();
              if (!_matchesDirectionScope(row, _selectedKind)) {
                return false;
              }
              if (_selectedGroup != null && _selectedGroup != group) {
                return false;
              }
              return (row['price_active'] ?? true) == true;
            })
            .map(
              (row) =>
                  (row['counterparty_name'] ?? '').toString().toUpperCase(),
            )
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<String> get _availableMaterials {
    final values =
        _priceRows
            .where((row) {
              final group = (row['group_code'] ?? '').toString().toUpperCase();
              final counterparty = (row['counterparty_name'] ?? '')
                  .toString()
                  .toUpperCase();
              if (!_matchesDirectionScope(row, _selectedKind)) {
                return false;
              }
              if (_selectedGroup != null && _selectedGroup != group) {
                return false;
              }
              if (_selectedCounterparty != null &&
                  _selectedCounterparty != counterparty) {
                return false;
              }
              return (row['price_active'] ?? true) == true;
            })
            .map(
              (row) => (row['material_label_snapshot'] ?? '')
                  .toString()
                  .toUpperCase(),
            )
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<Map<String, dynamic>> get _selectedRows {
    return _filteredRows
        .where(
          (row) =>
              _selectedPriceIds.contains((row['price_id'] ?? '').toString()),
        )
        .toList(growable: false);
  }

  List<Map<String, dynamic>> get _filteredHistoryRows {
    final visibleIds = _filteredRows
        .map((row) => (row['price_id'] ?? '').toString())
        .toSet();
    return _historyRows
        .where((row) => visibleIds.contains((row['price_id'] ?? '').toString()))
        .toList(growable: false);
  }

  List<String> get _availableHistoryCounterparties {
    final values =
        _historyRows
            .map(
              (row) =>
                  (row['counterparty_name'] ?? '').toString().toUpperCase(),
            )
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<String> get _availableHistoryMaterials {
    final values =
        _historyRows
            .map(
              (row) => (row['material_label_snapshot'] ?? '')
                  .toString()
                  .toUpperCase(),
            )
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<Map<String, dynamic>> get _workspaceHistoryRows {
    bool matchesMovement(Map<String, dynamic> row) {
      final previous = (row['previous_price'] as num?)?.toDouble();
      final current = ((row['new_price'] ?? 0) as num).toDouble();
      switch (_historyMovementFilter) {
        case 'altas':
          return previous == null || current > previous;
        case 'bajas':
          return previous != null && current < previous;
        case 'sin_cambio':
          return previous != null && current == previous;
        default:
          return true;
      }
    }

    bool matchesDate(Map<String, dynamic> row) {
      final createdAt = DateTime.tryParse(
        (row['created_at'] ?? '').toString(),
      )?.toLocal();
      if (createdAt == null) return false;
      final createdDate = DateUtils.dateOnly(createdAt);
      if (_historyDateRange != null &&
          createdDate.isBefore(DateUtils.dateOnly(_historyDateRange!.start))) {
        return false;
      }
      if (_historyDateRange != null &&
          createdDate.isAfter(DateUtils.dateOnly(_historyDateRange!.end))) {
        return false;
      }
      return true;
    }

    return _historyRows
        .where((row) {
          final counterparty = (row['counterparty_name'] ?? '')
              .toString()
              .toUpperCase();
          final material = (row['material_label_snapshot'] ?? '')
              .toString()
              .toUpperCase();
          if (_historyCounterpartyFilter != null &&
              _historyCounterpartyFilter != counterparty) {
            return false;
          }
          if (_historyMaterialFilter != null &&
              _historyMaterialFilter != material) {
            return false;
          }
          return matchesMovement(row) && matchesDate(row);
        })
        .toList(growable: false);
  }

  bool _isEditingTextField() {
    final focusedWidget = FocusManager.instance.primaryFocus?.context?.widget;
    return focusedWidget is EditableText;
  }

  GlobalKey _rowKeyFor(String priceId) =>
      _rowKeys.putIfAbsent(priceId, () => GlobalKey(debugLabel: priceId));

  void _ensureActiveRowVisible(String? priceId) {
    if (priceId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _rowKeyFor(priceId).currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: 0.28,
      );
    });
  }

  int _indexOfFilteredPrice(String priceId) => _visiblePriceRows.indexWhere(
    (row) => (row['price_id'] ?? '').toString() == priceId,
  );

  Iterable<String> _priceRange(String startId, String endId) sync* {
    final rows = _visiblePriceRows;
    final startIndex = _indexOfFilteredPrice(startId);
    final endIndex = _indexOfFilteredPrice(endId);
    if (startIndex < 0 || endIndex < 0) return;
    final from = startIndex < endIndex ? startIndex : endIndex;
    final to = startIndex < endIndex ? endIndex : startIndex;
    for (var i = from; i <= to; i++) {
      yield (rows[i]['price_id'] ?? '').toString();
    }
  }

  void _selectSinglePrice(String priceId) {
    setState(() {
      _activePriceId = priceId;
      _selectionAnchorPriceId = priceId;
      _selectedPriceIds
        ..clear()
        ..add(priceId);
    });
    _ensureActiveRowVisible(priceId);
  }

  void _toggleAccumulatedPrice(String priceId) {
    setState(() {
      _activePriceId = priceId;
      _selectionAnchorPriceId ??= priceId;
      if (_selectedPriceIds.contains(priceId)) {
        _selectedPriceIds.remove(priceId);
      } else {
        _selectedPriceIds.add(priceId);
      }
    });
    _ensureActiveRowVisible(priceId);
  }

  void _selectRangeTo(String priceId) {
    final anchorId = _selectionAnchorPriceId ?? _activePriceId ?? priceId;
    setState(() {
      _activePriceId = priceId;
      _selectionAnchorPriceId = anchorId;
      _selectedPriceIds
        ..clear()
        ..addAll(_priceRange(anchorId, priceId));
    });
    _ensureActiveRowVisible(priceId);
  }

  void _handleRowActivate(String priceId) {
    final keyboard = HardwareKeyboard.instance;
    final additive = keyboard.isControlPressed || keyboard.isMetaPressed;
    if (keyboard.isShiftPressed) {
      _selectRangeTo(priceId);
      return;
    }
    if (additive) {
      _toggleAccumulatedPrice(priceId);
      return;
    }
    _selectSinglePrice(priceId);
  }

  void _beginRowDrag(String priceId) {
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed) {
      _dragSelecting = false;
      return;
    }
    _dragSelecting = true;
    _dragAnchorPriceId = priceId;
    _selectSinglePrice(priceId);
  }

  void _extendRowDrag(String priceId) {
    if (!_dragSelecting) return;
    final anchorId = _dragAnchorPriceId;
    if (anchorId == null) return;
    setState(() {
      _activePriceId = priceId;
      _selectionAnchorPriceId = anchorId;
      _selectedPriceIds
        ..clear()
        ..addAll(_priceRange(anchorId, priceId));
    });
    _ensureActiveRowVisible(priceId);
  }

  void _endRowDrag() {
    _dragSelecting = false;
    _dragAnchorPriceId = null;
  }

  void _moveActiveSelection(int delta, {required bool extend}) {
    final rows = _visiblePriceRows;
    if (rows.isEmpty) return;
    final currentIndex = _activePriceId == null
        ? -1
        : rows.indexWhere(
            (row) => (row['price_id'] ?? '').toString() == _activePriceId,
          );
    final baseIndex = currentIndex >= 0 ? currentIndex : 0;
    final nextIndex = (baseIndex + delta).clamp(0, rows.length - 1);
    final nextId = (rows[nextIndex]['price_id'] ?? '').toString();
    setState(() {
      _activePriceId = nextId;
      if (extend) {
        final anchorId = _selectionAnchorPriceId ?? nextId;
        _selectionAnchorPriceId = anchorId;
        final anchorIndex = rows.indexWhere(
          (row) => (row['price_id'] ?? '').toString() == anchorId,
        );
        final start = anchorIndex < nextIndex ? anchorIndex : nextIndex;
        final end = anchorIndex < nextIndex ? nextIndex : anchorIndex;
        _selectedPriceIds
          ..clear()
          ..addAll(
            rows
                .sublist(start, end + 1)
                .map((row) => (row['price_id'] ?? '').toString()),
          );
      } else {
        _selectionAnchorPriceId = nextId;
        _selectedPriceIds
          ..clear()
          ..add(nextId);
      }
    });
    _ensureActiveRowVisible(nextId);
  }

  double? _parseAdjustmentValue() {
    final parsed = double.tryParse(_adjustmentValueC.text.trim());
    if (parsed == null) return null;
    if (_adjustmentMode == 'delta_amount' && parsed >= 0) {
      return parsed * _deltaDirection;
    }
    return parsed;
  }

  double _computeNewPrice(double current) {
    final value = _parseAdjustmentValue() ?? 0;
    switch (_adjustmentMode) {
      case 'delta_amount':
        return current + value;
      case 'replace':
        return value;
      default:
        return current;
    }
  }

  String _formatMoney(num value) => formatMoney(value);

  String _modeLabel(String mode) {
    switch (mode) {
      case 'delta_amount':
        return 'Subir / bajar';
      case 'replace':
        return 'Fijar precio';
      default:
        return mode;
    }
  }

  String _modeInputLabel(String mode) {
    switch (mode) {
      case 'delta_amount':
        return 'Cantidad';
      case 'replace':
        return 'Precio final';
      default:
        return 'Valor';
    }
  }

  String _modeInputHint(String mode) {
    switch (mode) {
      case 'delta_amount':
        return 'Ej. 0.10 o -0.20';
      case 'replace':
        return 'Ej. 2.50';
      default:
        return '';
    }
  }

  String _historyEventLabel(String value) {
    switch (value) {
      case 'create':
        return 'Alta';
      case 'adjustment':
        return 'Ajuste';
      case 'direct_edit':
        return 'Edición puntual';
      case 'status_change':
        return 'Cambio de estado';
      default:
        return value.toUpperCase();
    }
  }

  String _historyModeLabel(String? value) {
    switch (value) {
      case 'delta_amount':
        return 'Subir / bajar';
      case 'replace':
        return 'Fijar precio';
      case null:
      case '':
        return 'Sin modo';
      default:
        return value.toUpperCase();
    }
  }

  String _formatHistoryDate(String? value) {
    final date = value == null ? null : DateTime.tryParse(value)?.toLocal();
    if (date == null) return 'Sin fecha';
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = date.year.toString();
    final hh = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy · $hh:$min';
  }

  String _formatAppliedBy(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return 'Sistema';
    return raw.length <= 8 ? raw : '${raw.substring(0, 8)}…';
  }

  String _formatShortDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
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

  Future<DateTimeRange?> _showHistoryDateRangeDialog({
    required BuildContext context,
    required DateTimeRange bounds,
    DateTimeRange? initialRange,
  }) async {
    return showDialog<DateTimeRange?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (dialogContext) {
        DateTime displayMonth = DateTime(
          (initialRange?.start ?? bounds.end).year,
          (initialRange?.start ?? bounds.end).month,
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
              final previewEnd = end ?? hover;

              DateTimeRange? buildResult() {
                if (start == null) return null;
                final a = dateOnly(start!);
                final b = dateOnly(end ?? start!);
                final from = a.isBefore(b) ? a : b;
                final to = a.isBefore(b) ? b : a;
                return DateTimeRange(start: from, end: to);
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
                                '${_monthNameEs(monthFirst.month)[0].toUpperCase()}${_monthNameEs(monthFirst.month).substring(1)} ${monthFirst.year}',
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
                          for (final label in [
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
                          final selectedStart =
                              start != null && isSameDay(day, start!);
                          final selectedEnd =
                              end != null && isSameDay(day, end!);
                          final preview = enabled && inPreviewRange(day);
                          return MouseRegion(
                            onEnter: (_) {
                              if (start != null && end == null && enabled) {
                                setLocalState(() => hover = day);
                              }
                            },
                            child: GestureDetector(
                              onTap: !enabled
                                  ? null
                                  : () {
                                      setLocalState(() {
                                        final tapped = dateOnly(day);
                                        if (start == null ||
                                            (start != null && end != null)) {
                                          start = tapped;
                                          end = null;
                                          hover = null;
                                        } else {
                                          end = tapped;
                                        }
                                      });
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                decoration: BoxDecoration(
                                  color: selectedStart || selectedEnd
                                      ? tokens.primaryStrong.withValues(
                                          alpha: 0.18,
                                        )
                                      : preview
                                      ? tokens.primarySoft.withValues(
                                          alpha: 0.24,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selectedStart || selectedEnd
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
                                      fontWeight: selectedStart || selectedEnd
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      color: !enabled
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
                            : '${_formatShortDate(start!)} - ${_formatShortDate(end!)}',
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
                            style: contractSecondaryButtonStyle(context),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: contractSecondaryButtonStyle(context),
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(null),
                            child: const Text('Limpiar'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: contractPrimaryButtonStyle(context),
                            onPressed: buildResult() == null
                                ? null
                                : () => Navigator.of(
                                    dialogContext,
                                  ).pop(buildResult()),
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

  Future<void> _applyAdjustments() async {
    if (_applying) return;
    if (_selectedPriceIds.isEmpty) {
      _toast('Selecciona al menos un precio');
      return;
    }
    final value = _parseAdjustmentValue();
    if (value == null) {
      _toast('Ingresa un valor de ajuste válido');
      return;
    }
    if (_adjustmentMode != 'replace' && value == 0) {
      _toast('El ajuste no puede ser cero');
      return;
    }
    final previewNegative = _selectedRows.any((row) {
      final current = ((row['final_price'] ?? 0) as num).toDouble();
      return _computeNewPrice(current) < 0;
    });
    if (previewNegative) {
      _toast('El ajuste genera al menos un precio negativo');
      return;
    }
    setState(() => _applying = true);
    try {
      await _supa.rpc(
        'apply_men_price_adjustment',
        params: <String, dynamic>{
          'p_price_ids': _selectedPriceIds.toList(growable: false),
          'p_adjustment_mode': _adjustmentMode,
          'p_adjustment_value': value,
          'p_reason': _reasonC.text.trim().isEmpty
              ? null
              : _reasonC.text.trim(),
        },
      );
      _toast('Ajuste aplicado a ${_selectedPriceIds.length} precios');
      _reasonC.clear();
      _adjustmentValueC.clear();
      await _loadRows();
    } on PostgrestException catch (e) {
      _toast('No se pudo aplicar el ajuste: ${e.message}');
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _showHistoryDialog() async {
    final selectedIds = _selectedPriceIds.isEmpty
        ? const <String>[]
        : _selectedPriceIds.toSet().toList(growable: false);
    try {
      dynamic query = _supa
          .from('vw_men_price_adjustment_history')
          .select()
          .order('created_at', ascending: false)
          .limit(600);
      if (selectedIds.isNotEmpty) {
        final orFilter = selectedIds
            .map((id) => 'price_id.eq.${id.replaceAll(',', r'\,')}')
            .join(',');
        query = query.or(orFilter);
      }
      final data = await query;
      final rows = (data as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
      if (rows.isEmpty) {
        _toast('No hay movimientos registrados para ese criterio');
        return;
      }
      if (!mounted) return;
      String movementFilter = 'todos';
      String? counterpartyFilter;
      String? materialFilter;
      DateTimeRange? dateRange;
      final rowDates = rows
          .map((row) => DateTime.tryParse((row['created_at'] ?? '').toString()))
          .whereType<DateTime>()
          .map((date) => DateUtils.dateOnly(date.toLocal()))
          .toList(growable: false);
      final minDate = rowDates.isEmpty
          ? DateTime.now().subtract(const Duration(days: 365))
          : rowDates.reduce((a, b) => a.isBefore(b) ? a : b);
      final maxDate = rowDates.isEmpty
          ? DateTime.now()
          : rowDates.reduce((a, b) => a.isAfter(b) ? a : b);
      final availableCounterparties =
          rows
              .map(
                (row) =>
                    (row['counterparty_name'] ?? '').toString().toUpperCase(),
              )
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      final availableMaterials =
          rows
              .map(
                (row) => (row['material_label_snapshot'] ?? '')
                    .toString()
                    .toUpperCase(),
              )
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AreaThemeScope(
          tokens: menudeoAreaTokens,
          child: StatefulBuilder(
            builder: (context, setLocalState) {
              bool matchesMovement(Map<String, dynamic> row) {
                final previous = (row['previous_price'] as num?)?.toDouble();
                final current = ((row['new_price'] ?? 0) as num).toDouble();
                switch (movementFilter) {
                  case 'altas':
                    return previous == null || current > previous;
                  case 'bajas':
                    return previous != null && current < previous;
                  case 'sin_cambio':
                    return previous != null && current == previous;
                  default:
                    return true;
                }
              }

              bool matchesTime(Map<String, dynamic> row) {
                final createdAt = DateTime.tryParse(
                  (row['created_at'] ?? '').toString(),
                )?.toLocal();
                if (createdAt == null) return false;
                final createdDate = DateUtils.dateOnly(createdAt);
                if (dateRange != null &&
                    createdDate.isBefore(
                      DateUtils.dateOnly(dateRange!.start),
                    )) {
                  return false;
                }
                if (dateRange != null &&
                    createdDate.isAfter(DateUtils.dateOnly(dateRange!.end))) {
                  return false;
                }
                return true;
              }

              bool matchesGridFilters(Map<String, dynamic> row) {
                final counterparty = (row['counterparty_name'] ?? '')
                    .toString()
                    .toUpperCase();
                final material = (row['material_label_snapshot'] ?? '')
                    .toString()
                    .toUpperCase();
                if (counterpartyFilter != null &&
                    counterpartyFilter != counterparty) {
                  return false;
                }
                if (materialFilter != null && materialFilter != material) {
                  return false;
                }
                return true;
              }

              bool matchesQuery(Map<String, dynamic> row) {
                return true;
              }

              final filteredRows = rows
                  .where((row) {
                    return matchesMovement(row) &&
                        matchesTime(row) &&
                        matchesGridFilters(row) &&
                        matchesQuery(row);
                  })
                  .toList(growable: false);
              final filteredPriceIds = filteredRows
                  .map((row) => (row['price_id'] ?? '').toString())
                  .where((id) => id.isNotEmpty)
                  .toSet();
              final hasSingleContext = filteredPriceIds.length == 1;
              final summary = filteredRows.isEmpty
                  ? (rows.isEmpty ? null : rows.first)
                  : filteredRows.first;

              return AlertDialog(
                title: Text(
                  hasSingleContext
                      ? 'Historial del precio'
                      : 'Historial de precios',
                ),
                content: SizedBox(
                  width: 860,
                  child: rows.isEmpty
                      ? const Text(
                          'No hay movimientos registrados para este precio.',
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasSingleContext && summary != null) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.66),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: menudeoAreaTokens.border.withValues(
                                      alpha: 0.74,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (summary['counterparty_name'] ?? '')
                                          .toString()
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: menudeoAreaTokens.primaryStrong,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (summary['material_label_snapshot'] ?? '')
                                          .toString()
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _HistoryInfoPill(
                                          label:
                                              'Grupo ${((summary['group_code'] ?? 'SIN GRUPO').toString().toUpperCase())}',
                                        ),
                                        _HistoryInfoPill(
                                          label:
                                              '${filteredRows.length} de ${rows.length} movimiento(s)',
                                        ),
                                        _HistoryInfoPill(
                                          label:
                                              'Vigente ${_formatMoney((summary['new_price'] as num?) ?? 0)}',
                                          highlighted: true,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _HistoryTrendStrip(
                                      points: _buildHistoryTrendPoints(
                                        filteredRows,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final clearButton =
                                    (counterpartyFilter != null ||
                                        materialFilter != null ||
                                        dateRange != null ||
                                        movementFilter != 'todos')
                                    ? OutlinedButton.icon(
                                        style: contractSecondaryButtonStyle(
                                          context,
                                        ),
                                        onPressed: () => setLocalState(() {
                                          counterpartyFilter = null;
                                          materialFilter = null;
                                          dateRange = null;
                                          movementFilter = 'todos';
                                        }),
                                        icon: const Icon(
                                          Icons.filter_alt_off_rounded,
                                        ),
                                        label: const Text('Limpiar filtros'),
                                      )
                                    : null;
                                if (constraints.maxWidth >= 980) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: _AdjustmentFilterField(
                                          label: 'Contraparte',
                                          value: counterpartyFilter,
                                          items: availableCounterparties,
                                          onChanged: (value) =>
                                              setLocalState(() {
                                                counterpartyFilter = value;
                                              }),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _AdjustmentFilterField(
                                          label: 'Material',
                                          value: materialFilter,
                                          items: availableMaterials,
                                          onChanged: (value) =>
                                              setLocalState(() {
                                                materialFilter = value;
                                              }),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _HistoryMovementField(
                                          value: movementFilter,
                                          onChanged: (value) =>
                                              setLocalState(() {
                                                movementFilter = value;
                                              }),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _HistoryDateRangeField(
                                          value: dateRange,
                                          onTap: () async {
                                            final picked =
                                                await _showHistoryDateRangeDialog(
                                                  context: context,
                                                  bounds: DateTimeRange(
                                                    start: minDate,
                                                    end: maxDate,
                                                  ),
                                                  initialRange: dateRange,
                                                );
                                            if (picked == null) {
                                              return;
                                            }
                                            setLocalState(() {
                                              dateRange = picked;
                                            });
                                          },
                                          onClear: dateRange == null
                                              ? null
                                              : () => setLocalState(() {
                                                  dateRange = null;
                                                }),
                                        ),
                                      ),
                                      if (clearButton != null) ...[
                                        const SizedBox(width: 10),
                                        clearButton,
                                      ],
                                    ],
                                  );
                                }
                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 220,
                                      child: _AdjustmentFilterField(
                                        label: 'Contraparte',
                                        value: counterpartyFilter,
                                        items: availableCounterparties,
                                        onChanged: (value) => setLocalState(() {
                                          counterpartyFilter = value;
                                        }),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 220,
                                      child: _AdjustmentFilterField(
                                        label: 'Material',
                                        value: materialFilter,
                                        items: availableMaterials,
                                        onChanged: (value) => setLocalState(() {
                                          materialFilter = value;
                                        }),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 220,
                                      child: _HistoryMovementField(
                                        value: movementFilter,
                                        onChanged: (value) => setLocalState(() {
                                          movementFilter = value;
                                        }),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 220,
                                      child: _HistoryDateRangeField(
                                        value: dateRange,
                                        onTap: () async {
                                          final picked =
                                              await _showHistoryDateRangeDialog(
                                                context: context,
                                                bounds: DateTimeRange(
                                                  start: minDate,
                                                  end: maxDate,
                                                ),
                                                initialRange: dateRange,
                                              );
                                          if (picked == null) {
                                            return;
                                          }
                                          setLocalState(() {
                                            dateRange = picked;
                                          });
                                        },
                                        onClear: dateRange == null
                                            ? null
                                            : () => setLocalState(() {
                                                dateRange = null;
                                              }),
                                      ),
                                    ),
                                    if (clearButton != null) ...[clearButton],
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            Flexible(
                              child: filteredRows.isEmpty
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(24),
                                        child: Text(
                                          'No hay movimientos para ese filtro.',
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: filteredRows.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 10),
                                      itemBuilder: (_, index) {
                                        final row = filteredRows[index];
                                        final previous =
                                            row['previous_price'] as num?;
                                        final current =
                                            (row['new_price'] as num?) ?? 0;
                                        final hasReason = (row['reason'] ?? '')
                                            .toString()
                                            .trim()
                                            .isNotEmpty;
                                        return Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.62,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: menudeoAreaTokens.border
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      '${previous == null ? 'ALTA' : _formatMoney(previous)} -> ${_formatMoney(current)}',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: menudeoAreaTokens
                                                            .primaryStrong,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatHistoryDate(
                                                      row['created_at']
                                                          ?.toString(),
                                                    ),
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 12,
                                                      color: menudeoAreaTokens
                                                          .badgeText,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  _HistoryInfoPill(
                                                    label: _historyEventLabel(
                                                      (row['event_kind'] ?? '')
                                                          .toString(),
                                                    ),
                                                  ),
                                                  _HistoryInfoPill(
                                                    label: _historyModeLabel(
                                                      row['adjustment_mode']
                                                          ?.toString(),
                                                    ),
                                                  ),
                                                  _HistoryInfoPill(
                                                    label:
                                                        'Usuario ${_formatAppliedBy(row['applied_by'])}',
                                                  ),
                                                ],
                                              ),
                                              if (hasReason) ...[
                                                const SizedBox(height: 8),
                                                Text(
                                                  (row['reason'] ?? '')
                                                      .toString(),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                ),
                actions: [
                  OutlinedButton(
                    style: contractSecondaryButtonStyle(dialogContext),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cerrar'),
                  ),
                ],
              );
            },
          ),
        ),
      );
    } on PostgrestException catch (e) {
      _toast('No se pudo cargar el historial: ${e.message}');
    }
  }

  Future<void> _showAdjustmentDialog() async {
    if (!mounted) return;
    setState(() {
      _selectedCounterparty = null;
      _selectedMaterial = null;
      _adjustmentMode = 'delta_amount';
      _deltaDirection = 1;
    });
    final dialogRowsScrollController = ScrollController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AreaThemeScope(
          tokens: menudeoAreaTokens,
          child: StatefulBuilder(
            builder: (context, setLocalState) {
              void refresh() {
                if (mounted) setState(() {});
                setLocalState(() {});
              }

              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ContractPopupSurface(
                  constraints: const BoxConstraints(
                    maxWidth: 980,
                    maxHeight: 860,
                  ),
                  padding: const EdgeInsets.all(18),
                  child: SingleChildScrollView(
                    child: _AdjustmentWorkspaceCard(
                      loading: _loading,
                      applying: _applying,
                      error: _error,
                      rows: _filteredRows,
                      selectedRows: _selectedRows,
                      selectedKind: _selectedKind,
                      selectedGroup: _selectedGroup,
                      selectedCounterparty: _selectedCounterparty,
                      selectedMaterial: _selectedMaterial,
                      activePriceId: _activePriceId,
                      availableKinds: _availableKinds,
                      availableGroups: _availableGroups,
                      availableCounterparties: _availableCounterparties,
                      availableMaterials: _availableMaterials,
                      adjustmentValueC: _adjustmentValueC,
                      reasonC: _reasonC,
                      adjustmentMode: _adjustmentMode == 'delta_percent'
                          ? 'delta_amount'
                          : _adjustmentMode,
                      formatMoney: _formatMoney,
                      modeLabel: _modeLabel,
                      modeInputLabel: _modeInputLabel,
                      modeInputHint: _modeInputHint,
                      computeNewPrice: _computeNewPrice,
                      onKindChanged: (value) {
                        setState(() {
                          _selectedKind = value;
                          if (_selectedGroup != null &&
                              !_availableGroups.contains(_selectedGroup)) {
                            _selectedGroup = null;
                          }
                          if (_selectedCounterparty != null &&
                              !_availableCounterparties.contains(
                                _selectedCounterparty,
                              )) {
                            _selectedCounterparty = null;
                          }
                          if (_selectedMaterial != null &&
                              !_availableMaterials.contains(
                                _selectedMaterial,
                              )) {
                            _selectedMaterial = null;
                          }
                        });
                        refresh();
                      },
                      onGroupChanged: (value) {
                        setState(() {
                          _selectedGroup = value;
                          if (_selectedCounterparty != null &&
                              !_availableCounterparties.contains(
                                _selectedCounterparty,
                              )) {
                            _selectedCounterparty = null;
                          }
                          if (_selectedMaterial != null &&
                              !_availableMaterials.contains(
                                _selectedMaterial,
                              )) {
                            _selectedMaterial = null;
                          }
                        });
                        refresh();
                      },
                      onCounterpartyChanged: (value) {
                        setState(() {
                          _selectedCounterparty = value;
                          if (_selectedMaterial != null &&
                              !_availableMaterials.contains(
                                _selectedMaterial,
                              )) {
                            _selectedMaterial = null;
                          }
                        });
                        refresh();
                      },
                      onMaterialChanged: (value) {
                        setState(() => _selectedMaterial = value);
                        refresh();
                      },
                      onModeChanged: (value) {
                        setState(() => _adjustmentMode = value);
                        refresh();
                      },
                      onAdjustmentValueChanged: (_) => refresh(),
                      deltaDirection: _deltaDirection,
                      onDeltaDirectionChanged: (value) {
                        setState(() => _deltaDirection = value);
                        refresh();
                      },
                      onToggleRow: (priceId, selected) {
                        if (selected) {
                          _handleRowActivate(priceId);
                        } else {
                          setState(() {
                            _activePriceId = priceId;
                            _selectionAnchorPriceId ??= priceId;
                            _selectedPriceIds.remove(priceId);
                          });
                          _ensureActiveRowVisible(priceId);
                        }
                        refresh();
                      },
                      onRowActivate: (priceId) {
                        _handleRowActivate(priceId);
                        refresh();
                      },
                      onRowDragStart: (priceId) {
                        _beginRowDrag(priceId);
                        refresh();
                      },
                      onRowDragEnter: (priceId) {
                        _extendRowDrag(priceId);
                        refresh();
                      },
                      onRowDragEnd: () {
                        _endRowDrag();
                        refresh();
                      },
                      onSelectAllVisible: () {
                        setState(() {
                          final firstId = _filteredRows.isEmpty
                              ? null
                              : (_filteredRows.first['price_id'] ?? '')
                                    .toString();
                          _activePriceId = firstId;
                          _selectionAnchorPriceId = firstId;
                          _selectedPriceIds
                            ..clear()
                            ..addAll(
                              _filteredRows.map(
                                (row) => (row['price_id'] ?? '').toString(),
                              ),
                            );
                        });
                        refresh();
                      },
                      onClearSelection: () {
                        setState(() {
                          _selectedPriceIds.clear();
                          _activePriceId = null;
                          _selectionAnchorPriceId = null;
                        });
                        refresh();
                      },
                      rowsScrollController: dialogRowsScrollController,
                      rowKeyFor: _rowKeyFor,
                      onApply: () async {
                        await _applyAdjustments();
                        refresh();
                      },
                      compactMode: true,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } finally {
      dialogRowsScrollController.dispose();
    }
  }

  Future<void> _downloadPreview() async {
    if (_selectedRows.isEmpty) {
      _toast('Selecciona al menos un precio para descargar la vista previa');
      return;
    }
    final csv = StringBuffer()
      ..writeln(
        'CONTRAPARTE,GRUPO,MATERIAL,PRECIO_ACTUAL,MODO,VALOR_AJUSTE,PRECIO_NUEVO',
      );
    final value = _parseAdjustmentValue() ?? 0;
    for (final row in _selectedRows) {
      final current = ((row['final_price'] ?? 0) as num).toDouble();
      final next = _computeNewPrice(current);
      csv.writeln(
        '"${(row['counterparty_name'] ?? '').toString().replaceAll('"', '""')}",'
        '"${(row['group_code'] ?? '').toString().replaceAll('"', '""')}",'
        '"${(row['material_label_snapshot'] ?? '').toString().replaceAll('"', '""')}",'
        '${current.toStringAsFixed(4)},'
        '"${_modeLabel(_adjustmentMode).toUpperCase()}",'
        '${value.toStringAsFixed(4)},'
        '${next.toStringAsFixed(4)}',
      );
    }
    await saveCsvFile(
      fileName:
          'menudeo_price_adjustment_preview_${DateTime.now().millisecondsSinceEpoch}.csv',
      content: csv.toString(),
      dialogTitle: 'Guardar vista previa',
    );
  }

  Future<void> _downloadProviderPriceReportPdf() async {
    final rowsForReport = _selectedRows.isNotEmpty
        ? _selectedRows
        : _filteredRows;
    if (rowsForReport.isEmpty) {
      _toast('No hay precios visibles para generar el reporte');
      return;
    }

    try {
      if (kIsWeb) {
        _toast('La exportación PDF en web no está habilitada aquí');
        return;
      }

      final baseDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Seleccionar carpeta base para reportes de menudeo',
        lockParentWindow: true,
      );
      if (baseDirectory == null || baseDirectory.trim().isEmpty) {
        _toast('Guardado cancelado');
        return;
      }

      pw.MemoryImage? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/images/logo_dicsa.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {
        logoImage = null;
      }

      final now = DateTime.now();
      final dateLabel =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      final dateSuffix =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${(now.year % 100).toString().padLeft(2, '0')}';
      final reportsRoot = Directory(
        '$baseDirectory${Platform.pathSeparator}Precios menudeo $dateSuffix',
      );
      await reportsRoot.create(recursive: true);

      final grouped =
          <String, Map<String, Map<String, List<Map<String, dynamic>>>>>{};
      for (final row in rowsForReport) {
        final direction = _rowDirectionLabel(row);
        final directionFolder = direction == 'VENTA' ? 'Ventas' : 'Compras';
        final group = _sanitizePathSegment(
          (row['group_code'] ?? 'SIN GRUPO').toString().toUpperCase(),
        );
        final counterparty = _sanitizePathSegment(
          (row['counterparty_name'] ?? 'SIN CONTRAPARTE')
              .toString()
              .toUpperCase(),
        );
        grouped
            .putIfAbsent(
              directionFolder,
              () => <String, Map<String, List<Map<String, dynamic>>>>{},
            )
            .putIfAbsent(group, () => <String, List<Map<String, dynamic>>>{})
            .putIfAbsent(counterparty, () => <Map<String, dynamic>>[])
            .add(row);
      }

      final accent = const PdfColor.fromInt(0xFF9A4D33);
      final softAccent = const PdfColor.fromInt(0xFFF4E6DE);
      final border = const PdfColor.fromInt(0xFFE7C8B8);
      final text = const PdfColor.fromInt(0xFF3A2A23);
      var writtenCount = 0;

      final directionFolders = grouped.keys.toList()..sort();
      for (final directionFolder in directionFolders) {
        final groups = grouped[directionFolder]!;
        final groupNames = groups.keys.toList()..sort();
        for (final groupName in groupNames) {
          final counterparties = groups[groupName]!;
          final counterpartyNames = counterparties.keys.toList()..sort();
          final targetDir = Directory(
            '${reportsRoot.path}${Platform.pathSeparator}$directionFolder${Platform.pathSeparator}$groupName',
          );
          await targetDir.create(recursive: true);

          for (final counterparty in counterpartyNames) {
            final providerRows = counterparties[counterparty]!
              ..sort((a, b) {
                final materialA = (a['material_label_snapshot'] ?? '')
                    .toString()
                    .toUpperCase();
                final materialB = (b['material_label_snapshot'] ?? '')
                    .toString()
                    .toUpperCase();
                return materialA.compareTo(materialB);
              });

            final doc = pw.Document();
            doc.addPage(
              pw.MultiPage(
                pageTheme: pw.PageTheme(
                  margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
                ),
                build: (_) => [
                  pw.Container(
                    padding: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(18),
                      border: pw.Border.all(color: border, width: 1.2),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Container(
                              width: 56,
                              height: 56,
                              decoration: pw.BoxDecoration(
                                color: softAccent,
                                borderRadius: pw.BorderRadius.circular(14),
                              ),
                              child: logoImage != null
                                  ? pw.Padding(
                                      padding: const pw.EdgeInsets.all(8),
                                      child: pw.Image(logoImage),
                                    )
                                  : pw.Center(
                                      child: pw.Text(
                                        'D',
                                        style: pw.TextStyle(
                                          color: accent,
                                          fontWeight: pw.FontWeight.bold,
                                          fontSize: 28,
                                        ),
                                      ),
                                    ),
                            ),
                            pw.SizedBox(width: 14),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'LISTA DE PRECIOS FINALES',
                                    style: pw.TextStyle(
                                      color: accent,
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: pw.BoxDecoration(
                                color: softAccent,
                                borderRadius: pw.BorderRadius.circular(12),
                              ),
                              child: pw.Text(
                                'VIGENCIA $dateLabel',
                                style: pw.TextStyle(
                                  color: accent,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 16),
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: pw.BoxDecoration(
                            color: softAccent,
                            borderRadius: pw.BorderRadius.circular(16),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                counterparty,
                                style: pw.TextStyle(
                                  color: accent,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                '$directionFolder · $groupName',
                                style: pw.TextStyle(
                                  color: text,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 16),
                        pw.Container(
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(16),
                            border: pw.Border.all(color: border, width: 1),
                          ),
                          child: pw.TableHelper.fromTextArray(
                            headers: const ['MATERIAL', 'PRECIO FINAL'],
                            data: providerRows
                                .map((row) {
                                  final current =
                                      ((row['final_price'] ?? 0) as num)
                                          .toDouble();
                                  return [
                                    (row['material_label_snapshot'] ?? '')
                                        .toString()
                                        .toUpperCase(),
                                    _formatMoney(current),
                                  ];
                                })
                                .toList(growable: false),
                            cellAlignment: pw.Alignment.centerLeft,
                            headerStyle: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                            cellStyle: pw.TextStyle(color: text, fontSize: 10),
                            headerDecoration: pw.BoxDecoration(
                              color: accent,
                              borderRadius: const pw.BorderRadius.only(
                                topLeft: pw.Radius.circular(15),
                                topRight: pw.Radius.circular(15),
                              ),
                            ),
                            rowDecoration: const pw.BoxDecoration(
                              color: PdfColors.white,
                            ),
                            oddRowDecoration: pw.BoxDecoration(
                              color: softAccent,
                            ),
                            border: pw.TableBorder(
                              horizontalInside: pw.BorderSide(
                                color: border,
                                width: 0.7,
                              ),
                            ),
                            headerPadding: const pw.EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            cellPadding: const pw.EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            columnWidths: <int, pw.TableColumnWidth>{
                              0: const pw.FlexColumnWidth(4),
                              1: const pw.FlexColumnWidth(1.5),
                            },
                          ),
                        ),
                        pw.SizedBox(height: 12),
                        pw.Text(
                          'Este documento refleja los precios finales vigentes al momento de su emisión.',
                          style: pw.TextStyle(color: text, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

            final fileName =
                '${_sanitizePathSegment(counterparty)} $dateSuffix.pdf';
            final file = File(
              '${targetDir.path}${Platform.pathSeparator}$fileName',
            );
            await file.writeAsBytes(await doc.save(), flush: true);
            writtenCount += 1;
          }
        }
      }

      _toast('Se generaron $writtenCount PDF(s) en ${reportsRoot.path}');
    } catch (e) {
      _toast('No se pudo generar el PDF: $e');
    }
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

  Future<void> _openTicketsPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoTicketsPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openSalesPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoSalesPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openDepositsExpensesPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoDepositsExpensesPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  void _showStub(String label) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label quedará conectado en la siguiente fase de Menudeo.',
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
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      case 'Tickets de menudeo':
        unawaited(_openTicketsPage());
        return;
      case 'Ventas menudeo':
        unawaited(_openSalesPage());
        return;
      case 'Depósitos y gastos':
        unawaited(_openDepositsExpensesPage());
        return;
      default:
        if (_menuOpen) setState(() => _menuOpen = false);
        _showStub(label);
    }
  }

  Future<void> _logout() async {
    final ok = await showMenudeoSessionConfirmDialog(context);
    if (ok != true || !mounted) return;
    await signOutAndRouteToLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    return AreaThemeScope(
      tokens: menudeoAreaTokens,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape && _menuOpen) {
            setState(() => _menuOpen = false);
            return KeyEventResult.handled;
          }
          if (_menuOpen || _isEditingTextField()) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _moveActiveSelection(
              1,
              extend: HardwareKeyboard.instance.isShiftPressed,
            );
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _moveActiveSelection(
              -1,
              extend: HardwareKeyboard.instance.isShiftPressed,
            );
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AppShell(
          background: const _MenudeoPriceAdjustmentsBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 6,
          padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
          leadingBuilder: (_, _) => _PriceAdjustHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, animation) => _PriceAdjustBrand(
            contentAnim: animation,
            title: 'Ajuste de precios',
          ),
          trailingBuilder: (_, _) => _PriceAdjustHeaderButton(
            label: 'Cerrar sesión',
            icon: Icons.logout_rounded,
            onTap: _logout,
          ),
          child: Stack(
            children: [
              _PriceAdjustBody(
                loading: _loading,
                applying: _applying,
                error: _error,
                rows: _visiblePriceRows,
                filteredRowCount: _filteredRows.length,
                currentPage: _effectiveCurrentPageFor(_filteredRows.length),
                totalPages: _totalPagesFor(_filteredRows.length),
                pageSize: _pageSize,
                selectedRows: _selectedRows,
                historyRows: _filteredHistoryRows,
                selectedKind: _selectedKind,
                selectedGroup: _selectedGroup,
                selectedCounterparty: _selectedCounterparty,
                selectedMaterial: _selectedMaterial,
                availableKinds: _availableKinds,
                availableGroups: _availableGroups,
                availableCounterparties: _availableCounterparties,
                availableMaterials: _availableMaterials,
                adjustmentValueC: _adjustmentValueC,
                reasonC: _reasonC,
                adjustmentMode: _adjustmentMode == 'delta_percent'
                    ? 'delta_amount'
                    : _adjustmentMode,
                formatMoney: _formatMoney,
                modeLabel: _modeLabel,
                modeInputLabel: _modeInputLabel,
                modeInputHint: _modeInputHint,
                computeNewPrice: _computeNewPrice,
                onShowHistory: _showHistoryDialog,
                onDownloadProviderPdf: _downloadProviderPriceReportPdf,
                onDownloadPreview: _downloadPreview,
                onOpenAdjustmentDialog: _showAdjustmentDialog,
                onApply: _applyAdjustments,
                onKindChanged: (value) => setState(() {
                  _selectedKind = value;
                  _currentPage = 0;
                  if (_selectedGroup != null &&
                      !_availableGroups.contains(_selectedGroup)) {
                    _selectedGroup = null;
                  }
                  if (_selectedCounterparty != null &&
                      !_availableCounterparties.contains(
                        _selectedCounterparty,
                      )) {
                    _selectedCounterparty = null;
                  }
                  if (_selectedMaterial != null &&
                      !_availableMaterials.contains(_selectedMaterial)) {
                    _selectedMaterial = null;
                  }
                }),
                onGroupChanged: (value) => setState(() {
                  _selectedGroup = value;
                  _currentPage = 0;
                  if (_selectedCounterparty != null &&
                      !_availableCounterparties.contains(
                        _selectedCounterparty,
                      )) {
                    _selectedCounterparty = null;
                  }
                  if (_selectedMaterial != null &&
                      !_availableMaterials.contains(_selectedMaterial)) {
                    _selectedMaterial = null;
                  }
                }),
                onCounterpartyChanged: (value) => setState(() {
                  _selectedCounterparty = value;
                  _currentPage = 0;
                  if (_selectedMaterial != null &&
                      !_availableMaterials.contains(_selectedMaterial)) {
                    _selectedMaterial = null;
                  }
                }),
                onMaterialChanged: (value) => setState(() {
                  _selectedMaterial = value;
                  _currentPage = 0;
                }),
                onModeChanged: (value) =>
                    setState(() => _adjustmentMode = value),
                deltaDirection: _deltaDirection,
                onDeltaDirectionChanged: (value) =>
                    setState(() => _deltaDirection = value),
                onToggleRow: (priceId, selected) {
                  if (selected) {
                    _handleRowActivate(priceId);
                  } else {
                    setState(() {
                      _activePriceId = priceId;
                      _selectionAnchorPriceId ??= priceId;
                      _selectedPriceIds.remove(priceId);
                    });
                    _ensureActiveRowVisible(priceId);
                  }
                },
                onRowActivate: _handleRowActivate,
                onRowDragStart: _beginRowDrag,
                onRowDragEnter: _extendRowDrag,
                onRowDragEnd: _endRowDrag,
                onSelectAllVisible: () {
                  setState(() {
                    final firstId = _visiblePriceRows.isEmpty
                        ? null
                        : (_visiblePriceRows.first['price_id'] ?? '')
                              .toString();
                    _activePriceId = firstId;
                    _selectionAnchorPriceId = firstId;
                    _selectedPriceIds
                      ..clear()
                      ..addAll(
                        _visiblePriceRows.map(
                          (row) => (row['price_id'] ?? '').toString(),
                        ),
                      );
                  });
                },
                onPreviousPage:
                    _effectiveCurrentPageFor(_filteredRows.length) > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                onNextPage:
                    _effectiveCurrentPageFor(_filteredRows.length) <
                        _totalPagesFor(_filteredRows.length) - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                onPageSizeChanged: (value) {
                  setState(() {
                    _pageSize = value;
                    _currentPage = 0;
                  });
                },
                onClearSelection: () => setState(() {
                  _selectedPriceIds.clear();
                  _activePriceId = null;
                  _selectionAnchorPriceId = null;
                }),
                insightsOpen: _insightsOpen,
                insightsTriggerHovered: _insightsTriggerHovered,
                onInsightsToggle: () =>
                    setState(() => _insightsOpen = !_insightsOpen),
                onInsightsTriggerHoverChanged: (hovered) =>
                    setState(() => _insightsTriggerHovered = hovered),
                minBodyHeight: viewportHeight - 160,
                activePriceId: _activePriceId,
                rowsScrollController: _rowsScrollC,
                rowKeyFor: _rowKeyFor,
                workspaceHistoryRows: _workspaceHistoryRows,
                availableHistoryCounterparties: _availableHistoryCounterparties,
                availableHistoryMaterials: _availableHistoryMaterials,
                historyMovementFilter: _historyMovementFilter,
                historyCounterpartyFilter: _historyCounterpartyFilter,
                historyMaterialFilter: _historyMaterialFilter,
                historyDateRange: _historyDateRange,
                onHistoryMovementChanged: (value) =>
                    setState(() => _historyMovementFilter = value),
                onHistoryCounterpartyChanged: (value) =>
                    setState(() => _historyCounterpartyFilter = value),
                onHistoryMaterialChanged: (value) =>
                    setState(() => _historyMaterialFilter = value),
                onHistoryDateRangeChanged: (value) =>
                    setState(() => _historyDateRange = value),
                onClearHistoryFilters: () => setState(() {
                  _historyMovementFilter = 'todos';
                  _historyCounterpartyFilter = null;
                  _historyMaterialFilter = null;
                  _historyDateRange = null;
                }),
                onPickHistoryDateRange: (initialRange, bounds) =>
                    _showHistoryDateRangeDialog(
                      context: context,
                      bounds: bounds,
                      initialRange: initialRange,
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
                  child: _PriceAdjustSidePanel(
                    onNavigate: _handleNavigationAction,
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

class _PriceAdjustBody extends StatelessWidget {
  final double minBodyHeight;
  final bool loading;
  final bool applying;
  final String? error;
  final List<Map<String, dynamic>> rows;
  final int filteredRowCount;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final List<Map<String, dynamic>> selectedRows;
  final List<Map<String, dynamic>> historyRows;
  final String? selectedKind;
  final String? selectedGroup;
  final String? selectedCounterparty;
  final String? selectedMaterial;
  final String? activePriceId;
  final List<String> availableKinds;
  final List<String> availableGroups;
  final List<String> availableCounterparties;
  final List<String> availableMaterials;
  final TextEditingController adjustmentValueC;
  final TextEditingController reasonC;
  final String adjustmentMode;
  final String Function(num value) formatMoney;
  final String Function(String mode) modeLabel;
  final String Function(String mode) modeInputLabel;
  final String Function(String mode) modeInputHint;
  final double Function(double current) computeNewPrice;
  final Future<void> Function() onShowHistory;
  final Future<void> Function() onDownloadProviderPdf;
  final Future<void> Function() onDownloadPreview;
  final Future<void> Function() onOpenAdjustmentDialog;
  final Future<void> Function() onApply;
  final ValueChanged<String?> onKindChanged;
  final ValueChanged<String?> onGroupChanged;
  final ValueChanged<String?> onCounterpartyChanged;
  final ValueChanged<String?> onMaterialChanged;
  final ValueChanged<String> onModeChanged;
  final int deltaDirection;
  final ValueChanged<int> onDeltaDirectionChanged;
  final void Function(String priceId, bool selected) onToggleRow;
  final ValueChanged<String> onRowActivate;
  final ValueChanged<String> onRowDragStart;
  final ValueChanged<String> onRowDragEnter;
  final VoidCallback onRowDragEnd;
  final VoidCallback onSelectAllVisible;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<int> onPageSizeChanged;
  final VoidCallback onClearSelection;
  final bool insightsOpen;
  final bool insightsTriggerHovered;
  final VoidCallback onInsightsToggle;
  final ValueChanged<bool> onInsightsTriggerHoverChanged;
  final ScrollController rowsScrollController;
  final GlobalKey Function(String priceId) rowKeyFor;
  final List<Map<String, dynamic>> workspaceHistoryRows;
  final List<String> availableHistoryCounterparties;
  final List<String> availableHistoryMaterials;
  final String historyMovementFilter;
  final String? historyCounterpartyFilter;
  final String? historyMaterialFilter;
  final DateTimeRange? historyDateRange;
  final ValueChanged<String> onHistoryMovementChanged;
  final ValueChanged<String?> onHistoryCounterpartyChanged;
  final ValueChanged<String?> onHistoryMaterialChanged;
  final ValueChanged<DateTimeRange?> onHistoryDateRangeChanged;
  final VoidCallback onClearHistoryFilters;
  final Future<DateTimeRange?> Function(
    DateTimeRange? initialRange,
    DateTimeRange bounds,
  )
  onPickHistoryDateRange;

  const _PriceAdjustBody({
    required this.minBodyHeight,
    required this.loading,
    required this.applying,
    required this.error,
    required this.rows,
    required this.filteredRowCount,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.selectedRows,
    required this.historyRows,
    required this.selectedKind,
    required this.selectedGroup,
    required this.selectedCounterparty,
    required this.selectedMaterial,
    required this.activePriceId,
    required this.availableKinds,
    required this.availableGroups,
    required this.availableCounterparties,
    required this.availableMaterials,
    required this.adjustmentValueC,
    required this.reasonC,
    required this.adjustmentMode,
    required this.formatMoney,
    required this.modeLabel,
    required this.modeInputLabel,
    required this.modeInputHint,
    required this.computeNewPrice,
    required this.onShowHistory,
    required this.onDownloadProviderPdf,
    required this.onDownloadPreview,
    required this.onOpenAdjustmentDialog,
    required this.onApply,
    required this.onKindChanged,
    required this.onGroupChanged,
    required this.onCounterpartyChanged,
    required this.onMaterialChanged,
    required this.onModeChanged,
    required this.deltaDirection,
    required this.onDeltaDirectionChanged,
    required this.onToggleRow,
    required this.onRowActivate,
    required this.onRowDragStart,
    required this.onRowDragEnter,
    required this.onRowDragEnd,
    required this.onSelectAllVisible,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPageSizeChanged,
    required this.onClearSelection,
    required this.insightsOpen,
    required this.insightsTriggerHovered,
    required this.onInsightsToggle,
    required this.onInsightsTriggerHoverChanged,
    required this.rowsScrollController,
    required this.rowKeyFor,
    required this.workspaceHistoryRows,
    required this.availableHistoryCounterparties,
    required this.availableHistoryMaterials,
    required this.historyMovementFilter,
    required this.historyCounterpartyFilter,
    required this.historyMaterialFilter,
    required this.historyDateRange,
    required this.onHistoryMovementChanged,
    required this.onHistoryCounterpartyChanged,
    required this.onHistoryMaterialChanged,
    required this.onHistoryDateRangeChanged,
    required this.onClearHistoryFilters,
    required this.onPickHistoryDateRange,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Padding(
          padding: const EdgeInsets.only(left: 56, right: 2, bottom: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final historyListHeight = (constraints.maxHeight - 148).clamp(
                320.0,
                900.0,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppGlassToolbarPanel(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          style: contractPrimaryButtonStyle(context),
                          onPressed: rows.isEmpty
                              ? null
                              : onOpenAdjustmentDialog,
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('Nuevo ajuste'),
                        ),
                        OutlinedButton.icon(
                          style: contractSecondaryButtonStyle(context),
                          onPressed: rows.isEmpty
                              ? null
                              : onDownloadProviderPdf,
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('Descargar PDF'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _AdjustmentHistoryWorkspaceCard(
                      historyRows: workspaceHistoryRows,
                      allHistoryRows: historyRows,
                      availableCounterparties: availableHistoryCounterparties,
                      availableMaterials: availableHistoryMaterials,
                      movementFilter: historyMovementFilter,
                      counterpartyFilter: historyCounterpartyFilter,
                      materialFilter: historyMaterialFilter,
                      dateRange: historyDateRange,
                      onMovementChanged: onHistoryMovementChanged,
                      onCounterpartyChanged: onHistoryCounterpartyChanged,
                      onMaterialChanged: onHistoryMaterialChanged,
                      onDateRangeChanged: onHistoryDateRangeChanged,
                      onClearFilters: onClearHistoryFilters,
                      formatMoney: formatMoney,
                      onPickDateRange: onPickHistoryDateRange,
                      showHeader: false,
                      maxListHeight: historyListHeight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: MenudeoGridPager(
                      currentPage: currentPage,
                      totalPages: totalPages,
                      pageSize: pageSize,
                      totalRows: filteredRowCount,
                      onPrevious: onPreviousPage,
                      onNext: onNextPage,
                      onPageSizeChanged: onPageSizeChanged,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AdjustmentWorkspaceCard extends StatelessWidget {
  final bool loading;
  final bool applying;
  final String? error;
  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> selectedRows;
  final String? selectedKind;
  final String? selectedGroup;
  final String? selectedCounterparty;
  final String? selectedMaterial;
  final String? activePriceId;
  final List<String> availableKinds;
  final List<String> availableGroups;
  final List<String> availableCounterparties;
  final List<String> availableMaterials;
  final TextEditingController adjustmentValueC;
  final TextEditingController reasonC;
  final String adjustmentMode;
  final String Function(num value) formatMoney;
  final String Function(String mode) modeLabel;
  final String Function(String mode) modeInputLabel;
  final String Function(String mode) modeInputHint;
  final double Function(double current) computeNewPrice;
  final ValueChanged<String?> onKindChanged;
  final ValueChanged<String?> onGroupChanged;
  final ValueChanged<String?> onCounterpartyChanged;
  final ValueChanged<String?> onMaterialChanged;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<String>? onAdjustmentValueChanged;
  final int deltaDirection;
  final ValueChanged<int> onDeltaDirectionChanged;
  final void Function(String priceId, bool selected) onToggleRow;
  final ValueChanged<String> onRowActivate;
  final ValueChanged<String> onRowDragStart;
  final ValueChanged<String> onRowDragEnter;
  final VoidCallback onRowDragEnd;
  final VoidCallback onSelectAllVisible;
  final VoidCallback onClearSelection;
  final ScrollController rowsScrollController;
  final GlobalKey Function(String priceId) rowKeyFor;
  final Future<void> Function() onApply;
  final bool compactMode;

  const _AdjustmentWorkspaceCard({
    required this.loading,
    required this.applying,
    required this.error,
    required this.rows,
    required this.selectedRows,
    required this.selectedKind,
    required this.selectedGroup,
    required this.selectedCounterparty,
    required this.selectedMaterial,
    required this.activePriceId,
    required this.availableKinds,
    required this.availableGroups,
    required this.availableCounterparties,
    required this.availableMaterials,
    required this.adjustmentValueC,
    required this.reasonC,
    required this.adjustmentMode,
    required this.formatMoney,
    required this.modeLabel,
    required this.modeInputLabel,
    required this.modeInputHint,
    required this.computeNewPrice,
    required this.onKindChanged,
    required this.onGroupChanged,
    required this.onCounterpartyChanged,
    required this.onMaterialChanged,
    required this.onModeChanged,
    this.onAdjustmentValueChanged,
    required this.deltaDirection,
    required this.onDeltaDirectionChanged,
    required this.onToggleRow,
    required this.onRowActivate,
    required this.onRowDragStart,
    required this.onRowDragEnter,
    required this.onRowDragEnd,
    required this.onSelectAllVisible,
    required this.onClearSelection,
    required this.rowsScrollController,
    required this.rowKeyFor,
    required this.onApply,
    this.compactMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    if (compactMode) {
      return ContractGlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nuevo ajuste',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
            const SizedBox(height: 12),
            const _AdjustmentSectionTitle('1. Compra o venta'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ...availableKinds.map(
                  (kind) => _AdjustmentTag(
                    label: kind,
                    selected: selectedKind == kind,
                    onTap: () => onKindChanged(kind),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _AdjustmentSectionTitle('2. Grupo'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AdjustmentTag(
                  label: 'TODOS',
                  selected: selectedGroup == null,
                  onTap: () => onGroupChanged(null),
                ),
                ...availableGroups.map(
                  (group) => _AdjustmentTag(
                    label: group,
                    selected: selectedGroup == group,
                    onTap: () => onGroupChanged(group),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _AdjustmentSectionTitle('3. Seleccion'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  style: contractSecondaryButtonStyle(context),
                  onPressed: rows.isEmpty ? null : onSelectAllVisible,
                  icon: const Icon(Icons.select_all_rounded),
                  label: const Text('Seleccionar visibles'),
                ),
                OutlinedButton.icon(
                  style: contractSecondaryButtonStyle(context),
                  onPressed: selectedRows.isEmpty ? null : onClearSelection,
                  icon: const Icon(Icons.deselect_rounded),
                  label: const Text('Limpiar'),
                ),
                _AdjustmentMiniPill(label: '${rows.length} visibles'),
                _AdjustmentMiniPill(
                  label: '${selectedRows.length} seleccionados',
                  highlighted: selectedRows.isNotEmpty,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: tokens.surfaceTint.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: tokens.border.withValues(alpha: 0.76),
                ),
              ),
              child: loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          error!,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                  : rows.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No hay precios para ese criterio.'),
                      ),
                    )
                  : ListView.separated(
                      controller: rowsScrollController,
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final row = rows[index];
                        final priceId = (row['price_id'] ?? '').toString();
                        final selected = selectedRows.any(
                          (selectedRow) =>
                              (selectedRow['price_id'] ?? '').toString() ==
                              priceId,
                        );
                        final current = ((row['final_price'] ?? 0) as num)
                            .toDouble();
                        final next = selected
                            ? computeNewPrice(current)
                            : current;
                        return _AdjustmentUniverseRow(
                          key: rowKeyFor(priceId),
                          row: row,
                          selected: selected,
                          active: activePriceId == priceId,
                          currentPriceText: formatMoney(current),
                          nextPriceText: formatMoney(next),
                          onChanged: (value) => onToggleRow(priceId, value),
                          onActivate: () => onRowActivate(priceId),
                          onDragStart: () => onRowDragStart(priceId),
                          onDragEnter: () => onRowDragEnter(priceId),
                          onDragEnd: onRowDragEnd,
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            const _AdjustmentSectionTitle('4. Sube o baja'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _AdjustmentTag(
                    label: 'SUBIR',
                    selected: deltaDirection > 0,
                    onTap: () {
                      onModeChanged('delta_amount');
                      onDeltaDirectionChanged(1);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AdjustmentTag(
                    label: 'BAJAR',
                    selected: deltaDirection < 0,
                    onTap: () {
                      onModeChanged('delta_amount');
                      onDeltaDirectionChanged(-1);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: adjustmentValueC,
              onChanged: onAdjustmentValueChanged,
              keyboardType: const TextInputType.numberWithOptions(
                signed: false,
                decimal: true,
              ),
              decoration: _adjustmentFieldDecoration(
                context,
                hintText: 'Cantidad · Ej. 0.10',
                prefixIcon: Icon(
                  deltaDirection > 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonC,
              decoration: _adjustmentFieldDecoration(
                context,
                hintText: 'Referencia opcional',
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: contractPrimaryButtonStyle(context),
                onPressed: applying || selectedRows.isEmpty ? null : onApply,
                icon: Icon(
                  applying
                      ? Icons.hourglass_top_rounded
                      : Icons.done_all_rounded,
                ),
                label: Text(applying ? 'Aplicando...' : 'Aplicar'),
              ),
            ),
          ],
        ),
      );
    }
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compactMode) ...[
            Text(
              'Cambiar precios',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Trabaja sobre precios actuales. Filtra, selecciona, revisa el resultado y aplica el cambio sin duplicar movimientos.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: tokens.badgeText.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(height: 18),
          ],
          _AdjustmentSectionTitle(
            compactMode ? '1. Que precio cambiar' : '1. Alcance',
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              'SENTIDO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: tokens.badgeText,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _AdjustmentTag(
                label: 'TODOS',
                selected: selectedKind == null,
                onTap: () => onKindChanged(null),
              ),
              ...availableKinds.map(
                (kind) => _AdjustmentTag(
                  label: kind,
                  selected: selectedKind == kind,
                  onTap: () => onKindChanged(kind),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _AdjustmentTag(
                label: 'TODOS',
                selected: selectedGroup == null,
                onTap: () => onGroupChanged(null),
              ),
              ...availableGroups.map(
                (group) => _AdjustmentTag(
                  label: group,
                  selected: selectedGroup == group,
                  onTap: () => onGroupChanged(group),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AdjustmentFilterField(
                  label: 'Contraparte',
                  value: selectedCounterparty,
                  items: availableCounterparties,
                  onChanged: onCounterpartyChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AdjustmentFilterField(
                  label: 'Material',
                  value: selectedMaterial,
                  items: availableMaterials,
                  onChanged: onMaterialChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AdjustmentSectionTitle(
            compactMode ? '2. Como cambiarlo' : '2. Tipo de cambio',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AdjustmentModeCard(
                  icon: Icons.add_rounded,
                  title: 'Subir / bajar',
                  subtitle: 'Ej. subir 10 centavos',
                  active: adjustmentMode == 'delta_amount',
                  onTap: () => onModeChanged('delta_amount'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AdjustmentModeCard(
                  icon: Icons.edit_note_rounded,
                  title: 'Fijar precio',
                  subtitle: 'Ej. dejar en 2.50',
                  active: adjustmentMode == 'replace',
                  onTap: () => onModeChanged('replace'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (compactMode) ...[
            TextField(
              controller: adjustmentValueC,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: _adjustmentFieldDecoration(
                context,
                hintText:
                    '${modeInputLabel(adjustmentMode)} · ${modeInputHint(adjustmentMode)}',
                prefixIcon: const Icon(Icons.tune_rounded),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: adjustmentValueC,
                    onChanged: onAdjustmentValueChanged,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: _adjustmentFieldDecoration(
                      context,
                      hintText:
                          '${modeInputLabel(adjustmentMode)} · ${modeInputHint(adjustmentMode)}',
                      prefixIcon: const Icon(Icons.tune_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: reasonC,
                    decoration: _adjustmentFieldDecoration(
                      context,
                      hintText: 'Referencia',
                      prefixIcon: const Icon(Icons.notes_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!compactMode) ...[
            const SizedBox(height: 12),
            TextField(
              controller: reasonC,
              decoration: _adjustmentFieldDecoration(
                context,
                hintText: 'Referencia',
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _AdjustmentSectionTitle(
            compactMode ? '3. Antes y despues' : '3. Resultado',
          ),
          const SizedBox(height: 12),
          _AdjustmentPreviewSurface(
            loading: loading,
            error: error,
            rows: rows,
            selectedRows: selectedRows,
            adjustmentMode: adjustmentMode,
            adjustmentValueText: adjustmentValueC.text,
            formatMoney: formatMoney,
            modeLabel: modeLabel,
            computeNewPrice: computeNewPrice,
          ),
          const SizedBox(height: 16),
          _AdjustmentSectionTitle(
            compactMode ? '4. A quien aplicar' : '4. Universo afectado',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                style: contractSecondaryButtonStyle(context),
                onPressed: rows.isEmpty ? null : onSelectAllVisible,
                icon: const Icon(Icons.select_all_rounded),
                label: Text(
                  compactMode ? 'Seleccionar todo' : 'Seleccionar visibles',
                ),
              ),
              OutlinedButton.icon(
                style: contractSecondaryButtonStyle(context),
                onPressed: selectedRows.isEmpty ? null : onClearSelection,
                icon: const Icon(Icons.deselect_rounded),
                label: const Text('Limpiar'),
              ),
              _AdjustmentMiniPill(
                label: '${selectedRows.length} seleccionado(s)',
              ),
              ElevatedButton.icon(
                style: contractPrimaryButtonStyle(context),
                onPressed: applying || selectedRows.isEmpty ? null : onApply,
                icon: Icon(
                  applying
                      ? Icons.hourglass_top_rounded
                      : Icons.done_all_rounded,
                ),
                label: Text(
                  applying
                      ? 'Aplicando...'
                      : compactMode
                      ? 'Aplicar'
                      : 'Aplicar a ${selectedRows.length} precio(s)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 420),
            decoration: BoxDecoration(
              color: tokens.surfaceTint.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tokens.border.withValues(alpha: 0.76)),
            ),
            child: loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        error!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                : rows.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No hay precios para ese filtro.'),
                    ),
                  )
                : ListView.separated(
                    controller: rowsScrollController,
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final row = rows[index];
                      final priceId = (row['price_id'] ?? '').toString();
                      final selected = selectedRows.any(
                        (selectedRow) =>
                            (selectedRow['price_id'] ?? '').toString() ==
                            priceId,
                      );
                      final current = ((row['final_price'] ?? 0) as num)
                          .toDouble();
                      final next = selected
                          ? computeNewPrice(current)
                          : current;
                      return _AdjustmentUniverseRow(
                        key: rowKeyFor(priceId),
                        row: row,
                        selected: selected,
                        active: activePriceId == priceId,
                        currentPriceText: formatMoney(current),
                        nextPriceText: formatMoney(next),
                        onChanged: (value) => onToggleRow(priceId, value),
                        onActivate: () => onRowActivate(priceId),
                        onDragStart: () => onRowDragStart(priceId),
                        onDragEnter: () => onRowDragEnter(priceId),
                        onDragEnd: onRowDragEnd,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AdjustmentHistoryWorkspaceCard extends StatelessWidget {
  final List<Map<String, dynamic>> historyRows;
  final List<Map<String, dynamic>> allHistoryRows;
  final List<String> availableCounterparties;
  final List<String> availableMaterials;
  final String movementFilter;
  final String? counterpartyFilter;
  final String? materialFilter;
  final DateTimeRange? dateRange;
  final ValueChanged<String> onMovementChanged;
  final ValueChanged<String?> onCounterpartyChanged;
  final ValueChanged<String?> onMaterialChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final VoidCallback onClearFilters;
  final String Function(num value) formatMoney;
  final Future<DateTimeRange?> Function(
    DateTimeRange? initialRange,
    DateTimeRange bounds,
  )
  onPickDateRange;
  final bool showHeader;
  final double maxListHeight;

  const _AdjustmentHistoryWorkspaceCard({
    required this.historyRows,
    required this.allHistoryRows,
    required this.availableCounterparties,
    required this.availableMaterials,
    required this.movementFilter,
    required this.counterpartyFilter,
    required this.materialFilter,
    required this.dateRange,
    required this.onMovementChanged,
    required this.onCounterpartyChanged,
    required this.onMaterialChanged,
    required this.onDateRangeChanged,
    required this.onClearFilters,
    required this.formatMoney,
    required this.onPickDateRange,
    this.showHeader = true,
    this.maxListHeight = 520,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final rowDates = allHistoryRows
        .map((row) => DateTime.tryParse((row['created_at'] ?? '').toString()))
        .whereType<DateTime>()
        .map((date) => DateUtils.dateOnly(date.toLocal()))
        .toList(growable: false);
    final minDate = rowDates.isEmpty
        ? DateTime.now().subtract(const Duration(days: 365))
        : rowDates.reduce((a, b) => a.isBefore(b) ? a : b);
    final maxDate = rowDates.isEmpty
        ? DateTime.now()
        : rowDates.reduce((a, b) => a.isAfter(b) ? a : b);
    final filteredPriceIds = historyRows
        .map((row) => (row['price_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    final summary = historyRows.isEmpty ? null : historyRows.first;
    final showSingleTrend = filteredPriceIds.length == 1 && summary != null;

    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader) ...[
                Text(
                  'Movimientos recientes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: tokens.primaryStrong,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Usa los filtros para revisar qué cambió y abre un ajuste nuevo solo cuando ya tengas claro el universo.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: tokens.badgeText.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final clearVisible =
                      counterpartyFilter != null ||
                      materialFilter != null ||
                      dateRange != null ||
                      movementFilter != 'todos';
                  if (constraints.maxWidth >= 980) {
                    return Row(
                      children: [
                        Expanded(
                          child: _AdjustmentFilterField(
                            label: 'Contraparte',
                            value: counterpartyFilter,
                            items: availableCounterparties,
                            onChanged: onCounterpartyChanged,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AdjustmentFilterField(
                            label: 'Material',
                            value: materialFilter,
                            items: availableMaterials,
                            onChanged: onMaterialChanged,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _HistoryMovementField(
                            value: movementFilter,
                            onChanged: onMovementChanged,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _HistoryDateRangeField(
                            value: dateRange,
                            onTap: () async {
                              final picked = await onPickDateRange(
                                dateRange,
                                DateTimeRange(start: minDate, end: maxDate),
                              );
                              if (picked != null) onDateRangeChanged(picked);
                            },
                            onClear: dateRange == null
                                ? null
                                : () => onDateRangeChanged(null),
                          ),
                        ),
                        if (clearVisible) ...[
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            style: contractSecondaryButtonStyle(context),
                            onPressed: onClearFilters,
                            icon: const Icon(Icons.filter_alt_off_rounded),
                            label: const Text('Limpiar filtros'),
                          ),
                        ],
                      ],
                    );
                  }
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 220,
                        child: _AdjustmentFilterField(
                          label: 'Contraparte',
                          value: counterpartyFilter,
                          items: availableCounterparties,
                          onChanged: onCounterpartyChanged,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: _AdjustmentFilterField(
                          label: 'Material',
                          value: materialFilter,
                          items: availableMaterials,
                          onChanged: onMaterialChanged,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: _HistoryMovementField(
                          value: movementFilter,
                          onChanged: onMovementChanged,
                        ),
                      ),
                      _HistoryDateRangeField(
                        value: dateRange,
                        onTap: () async {
                          final picked = await onPickDateRange(
                            dateRange,
                            DateTimeRange(start: minDate, end: maxDate),
                          );
                          if (picked != null) onDateRangeChanged(picked);
                        },
                        onClear: dateRange == null
                            ? null
                            : () => onDateRangeChanged(null),
                      ),
                      if (clearVisible)
                        OutlinedButton.icon(
                          style: contractSecondaryButtonStyle(context),
                          onPressed: onClearFilters,
                          icon: const Icon(Icons.filter_alt_off_rounded),
                          label: const Text('Limpiar filtros'),
                        ),
                    ],
                  );
                },
              ),
              if (showSingleTrend) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.66),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: tokens.border.withValues(alpha: 0.74),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (summary['counterparty_name'] ?? '')
                            .toString()
                            .toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: tokens.primaryStrong,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (summary['material_label_snapshot'] ?? '')
                            .toString()
                            .toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _HistoryTrendStrip(
                        points: _buildHistoryTrendPoints(historyRows),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  constraints: BoxConstraints(maxHeight: maxListHeight),
                  decoration: BoxDecoration(
                    color: tokens.surfaceTint.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: tokens.border.withValues(alpha: 0.76),
                    ),
                  ),
                  child: historyRows.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No hay movimientos para ese filtro.'),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: historyRows.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final row = historyRows[index];
                            final previous = (row['previous_price'] as num?)
                                ?.toDouble();
                            final current = ((row['new_price'] ?? 0) as num)
                                .toDouble();
                            final movement = previous == null
                                ? 'ALTA'
                                : current > previous
                                ? 'SUBE'
                                : current < previous
                                ? 'BAJA'
                                : 'IGUAL';
                            final createdAt = DateTime.tryParse(
                              (row['created_at'] ?? '').toString(),
                            )?.toLocal();
                            final dateLabel = createdAt == null
                                ? '--/--/----'
                                : '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.76),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: tokens.border.withValues(alpha: 0.68),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 92,
                                    child: Text(
                                      dateLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: tokens.badgeText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      (row['counterparty_name'] ?? '')
                                          .toString()
                                          .toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        color: tokens.primaryStrong,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      (row['material_label_snapshot'] ?? '')
                                          .toString()
                                          .toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: tokens.badgeText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      previous == null
                                          ? '—'
                                          : formatMoney(previous),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: tokens.badgeText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      formatMoney(current),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        color: tokens.primaryStrong,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _HistoryInfoPill(
                                    label: movement,
                                    highlighted:
                                        movement == 'SUBE' ||
                                        movement == 'BAJA',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdjustmentUniverseRow extends StatefulWidget {
  final Map<String, dynamic> row;
  final bool selected;
  final bool active;
  final String currentPriceText;
  final String nextPriceText;
  final ValueChanged<bool> onChanged;
  final VoidCallback onActivate;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnter;
  final VoidCallback onDragEnd;

  const _AdjustmentUniverseRow({
    super.key,
    required this.row,
    required this.selected,
    required this.active,
    required this.currentPriceText,
    required this.nextPriceText,
    required this.onChanged,
    required this.onActivate,
    required this.onDragStart,
    required this.onDragEnter,
    required this.onDragEnd,
  });

  @override
  State<_AdjustmentUniverseRow> createState() => _AdjustmentUniverseRowState();
}

InputDecoration _adjustmentFieldDecoration(
  BuildContext context, {
  String? hintText,
  Widget? prefixIcon,
}) {
  return contractGlassFieldDecoration(
    context,
    hintText: hintText,
    prefixIcon: prefixIcon,
  ).copyWith(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

class _HistoryTrendPoint {
  final double price;
  final String label;

  const _HistoryTrendPoint({required this.price, required this.label});
}

List<_HistoryTrendPoint> _buildHistoryTrendPoints(
  List<Map<String, dynamic>> rows,
) {
  if (rows.isEmpty) return const <_HistoryTrendPoint>[];
  final ordered = List<Map<String, dynamic>>.from(rows)
    ..sort((a, b) {
      final aDate = DateTime.tryParse((a['created_at'] ?? '').toString());
      final bDate = DateTime.tryParse((b['created_at'] ?? '').toString());
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return -1;
      if (bDate == null) return 1;
      return aDate.compareTo(bDate);
    });

  String formatLabel(DateTime? date) {
    if (date == null) return '--/--';
    final local = date.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm\n$hh:$min';
  }

  final points = <_HistoryTrendPoint>[];
  final firstDate = DateTime.tryParse(
    (ordered.first['created_at'] ?? '').toString(),
  );
  final firstPrevious = (ordered.first['previous_price'] as num?)?.toDouble();
  if (firstPrevious != null) {
    points.add(
      _HistoryTrendPoint(price: firstPrevious, label: formatLabel(firstDate)),
    );
  }
  for (final row in ordered) {
    final current = ((row['new_price'] ?? 0) as num).toDouble();
    final createdAt = DateTime.tryParse((row['created_at'] ?? '').toString());
    points.add(
      _HistoryTrendPoint(price: current, label: formatLabel(createdAt)),
    );
  }
  return points;
}

class _AdjustmentUniverseRowState extends State<_AdjustmentUniverseRow> {
  bool _hovered = false;
  bool _suppressNextRowPointerDown = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final counterparty = (widget.row['counterparty_name'] ?? '').toString();
    final group = (widget.row['group_code'] ?? '').toString();
    final material = (widget.row['material_label_snapshot'] ?? '').toString();
    final hasChange = widget.currentPriceText != widget.nextPriceText;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovered = true);
        widget.onDragEnter();
      },
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (_) {
          if (_suppressNextRowPointerDown) {
            _suppressNextRowPointerDown = false;
            return;
          }
          widget.onDragStart();
        },
        onPointerUp: (_) => widget.onDragEnd(),
        onPointerCancel: (_) => widget.onDragEnd(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: widget.active
                ? tokens.primaryStrong.withValues(alpha: 0.14)
                : widget.selected
                ? tokens.primaryStrong.withValues(alpha: 0.10)
                : tokens.surfaceTint.withValues(alpha: _hovered ? 0.90 : 0.76),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.active
                  ? tokens.primaryStrong.withValues(alpha: 0.52)
                  : widget.selected
                  ? tokens.primaryStrong.withValues(alpha: 0.34)
                  : tokens.border.withValues(alpha: _hovered ? 0.90 : 0.70),
              width: widget.active ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.primaryStrong.withValues(
                  alpha: widget.active
                      ? 0.18
                      : widget.selected
                      ? 0.12
                      : (_hovered ? 0.08 : 0.04),
                ),
                blurRadius: widget.active
                    ? 24
                    : widget.selected
                    ? 20
                    : 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Listener(
                    onPointerDown: (_) {
                      _suppressNextRowPointerDown = true;
                    },
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => widget.onChanged(!widget.selected),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOutCubic,
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: widget.selected
                              ? tokens.primaryStrong.withValues(alpha: 0.18)
                              : tokens.badgeBackground.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: widget.selected
                                ? tokens.primaryStrong.withValues(alpha: 0.44)
                                : tokens.border.withValues(alpha: 0.78),
                            width: widget.selected ? 1.4 : 1,
                          ),
                          boxShadow: widget.selected
                              ? [
                                  BoxShadow(
                                    color: tokens.primaryStrong.withValues(
                                      alpha: 0.14,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : const [],
                        ),
                        child: Icon(
                          widget.selected
                              ? Icons.check_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 28,
                          color: widget.selected
                              ? tokens.primaryStrong
                              : tokens.primaryStrong.withValues(alpha: 0.52),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: widget.onActivate,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    counterparty,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      color: tokens.primaryStrong,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    material,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.badgeText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            _AdjustmentMiniPill(
                              label: group.isEmpty ? 'SIN GRUPO' : group,
                              highlighted: widget.selected,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _AdjustmentPriceChip(
                                      label: 'Actual',
                                      value: widget.currentPriceText,
                                    ),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                      color: hasChange
                                          ? tokens.primaryStrong
                                          : tokens.badgeText.withValues(
                                              alpha: 0.6,
                                            ),
                                    ),
                                    _AdjustmentPriceChip(
                                      label: 'Final',
                                      value: widget.nextPriceText,
                                      highlighted: hasChange,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _AdjustmentInsightsCard extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> selectedRows;
  final List<Map<String, dynamic>> historyRows;
  final String? selectedMaterial;

  const _AdjustmentInsightsCard({
    required this.rows,
    required this.selectedRows,
    required this.historyRows,
    required this.selectedMaterial,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final total = rows.length;
    final singleMaterialScope =
        selectedMaterial != null && selectedMaterial!.isNotEmpty;
    final visiblePrices = rows
        .map((row) => ((row['final_price'] ?? 0) as num).toDouble())
        .toList(growable: false);
    final minPrice = visiblePrices.isEmpty
        ? 0.0
        : visiblePrices.reduce((a, b) => a < b ? a : b);
    final maxPrice = visiblePrices.isEmpty
        ? 0.0
        : visiblePrices.reduce((a, b) => a > b ? a : b);
    final averagePrice = visiblePrices.isEmpty
        ? 0.0
        : visiblePrices.reduce((a, b) => a + b) / visiblePrices.length;
    final counterpartyCount = rows
        .map((row) => (row['counterparty_name'] ?? '').toString().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .length;
    final materialCount = rows
        .map(
          (row) =>
              (row['material_label_snapshot'] ?? '').toString().toUpperCase(),
        )
        .where((value) => value.isNotEmpty)
        .toSet()
        .length;
    final providerBuckets = <String, List<double>>{};
    final providerCounts = <String, int>{};
    final materialBuckets = <String, List<double>>{};
    final materialProviderBuckets = <String, Map<String, List<double>>>{};
    for (final row in rows) {
      final provider = ((row['counterparty_name'] ?? 'SIN NOMBRE')
          .toString()
          .toUpperCase());
      final material = ((row['material_label_snapshot'] ?? 'SIN MATERIAL')
          .toString()
          .toUpperCase());
      final price = ((row['final_price'] ?? 0) as num).toDouble();
      providerBuckets.putIfAbsent(provider, () => <double>[]).add(price);
      providerCounts.update(provider, (value) => value + 1, ifAbsent: () => 1);
      materialBuckets.putIfAbsent(material, () => <double>[]).add(price);
      materialProviderBuckets
          .putIfAbsent(material, () => <String, List<double>>{})
          .putIfAbsent(provider, () => <double>[])
          .add(price);
    }
    final providerAverages =
        providerBuckets.entries
            .map(
              (entry) => MapEntry(
                entry.key,
                entry.value.reduce((a, b) => a + b) / entry.value.length,
              ),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final topHighProviders = providerAverages.take(4).toList(growable: false);
    final topLowProviders = providerAverages.reversed
        .take(4)
        .toList(growable: false);
    final materialAverages =
        materialBuckets.entries
            .map(
              (entry) => MapEntry(
                entry.key,
                entry.value.reduce((a, b) => a + b) / entry.value.length,
              ),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final topHighMaterials = materialAverages.take(5).toList(growable: false);
    final topLowMaterials = materialAverages.reversed
        .take(5)
        .toList(growable: false);
    final materialSpreadEntries = materialBuckets.entries.map((entry) {
      final values = entry.value;
      final min = values.reduce((a, b) => a < b ? a : b);
      final max = values.reduce((a, b) => a > b ? a : b);
      return MapEntry(entry.key, (max - min).abs());
    }).toList()..sort((a, b) => b.value.compareTo(a.value));
    final materialMaxSpread = materialSpreadEntries.isEmpty
        ? 0.0
        : materialSpreadEntries.first.value;
    final materialMoves = <String, int>{};
    var upMoves = 0;
    var downMoves = 0;
    for (final row in historyRows) {
      final material = ((row['material_label_snapshot'] ?? 'SIN MATERIAL')
          .toString()
          .toUpperCase());
      materialMoves.update(material, (value) => value + 1, ifAbsent: () => 1);
      final previous = (row['previous_price'] as num?)?.toDouble();
      final current = ((row['new_price'] ?? 0) as num).toDouble();
      if (previous != null) {
        if (current > previous) upMoves++;
        if (current < previous) downMoves++;
      }
    }
    final topMaterials = materialMoves.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final chartProviders = providerCounts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        final avgA =
            providerBuckets[a.key]!.reduce((x, y) => x + y) /
            providerBuckets[a.key]!.length;
        final avgB =
            providerBuckets[b.key]!.reduce((x, y) => x + y) /
            providerBuckets[b.key]!.length;
        return avgB.compareTo(avgA);
      });
    final chartProviderLabels = chartProviders
        .take(5)
        .map((entry) => entry.key)
        .toList(growable: false);
    final materialChartEntries = materialBuckets.entries.toList()
      ..sort((a, b) {
        final spreadA = a.value.isEmpty
            ? 0.0
            : (a.value.reduce((x, y) => x > y ? x : y) -
                      a.value.reduce((x, y) => x < y ? x : y))
                  .abs();
        final spreadB = b.value.isEmpty
            ? 0.0
            : (b.value.reduce((x, y) => x > y ? x : y) -
                      b.value.reduce((x, y) => x < y ? x : y))
                  .abs();
        final bySpread = spreadB.compareTo(spreadA);
        if (bySpread != 0) return bySpread;
        return b.value.length.compareTo(a.value.length);
      });
    final chartGroups = materialChartEntries
        .take(6)
        .map((entry) {
          final providerMap = materialProviderBuckets[entry.key] ?? const {};
          return _MaterialSeriesGroup(
            label: entry.key,
            values: chartProviderLabels
                .map((provider) {
                  final providerValues = providerMap[provider];
                  if (providerValues == null || providerValues.isEmpty) {
                    return null;
                  }
                  return providerValues.reduce((a, b) => a + b) /
                      providerValues.length;
                })
                .toList(growable: false),
          );
        })
        .where((group) => group.values.any((value) => value != null))
        .toList(growable: false);
    final chartPalette = <Color>[
      tokens.primaryStrong,
      tokens.accent,
      tokens.primary,
      tokens.glow,
      tokens.primarySoft.withValues(alpha: 0.95),
    ];
    final chartSeries = List<_MaterialSeriesLegend>.generate(
      chartProviderLabels.length,
      (index) => _MaterialSeriesLegend(
        label: chartProviderLabels[index],
        color: chartPalette[index % chartPalette.length],
      ),
      growable: false,
    );
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vista rápida',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Distribución del filtro actual y lectura rápida de la selección.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tokens.badgeText,
            ),
          ),
          const SizedBox(height: 18),
          _InsightStatStrip(
            label: 'Filas visibles',
            value: '$total',
            accent: tokens.primaryStrong,
          ),
          const SizedBox(height: 10),
          _InsightStatStrip(
            label: 'Filas seleccionadas',
            value: '${selectedRows.length}',
            accent: tokens.accent,
          ),
          const SizedBox(height: 18),
          _PriceMiniSummary(
            minPrice: minPrice,
            maxPrice: maxPrice,
            averagePrice: averagePrice,
            counterpartyCount: counterpartyCount,
            materialCount: materialCount,
            showAverage: singleMaterialScope,
            spreadValue: materialMaxSpread,
          ),
          const SizedBox(height: 18),
          if (chartGroups.isNotEmpty && chartSeries.isNotEmpty)
            _MaterialSeriesChartCard(
              title: 'Precios por material',
              subtitle:
                  'Comparativo visible por contraparte para leer diferencias reales.',
              groups: chartGroups,
              legends: chartSeries,
            ),
          if (chartGroups.isNotEmpty && chartSeries.isNotEmpty)
            const SizedBox(height: 18),
          if (topMaterials.isNotEmpty)
            _MovementListCard(
              title: 'Materiales con mayor movimiento',
              items: topMaterials.take(6).toList(growable: false),
              upMoves: upMoves,
              downMoves: downMoves,
            ),
          if (topMaterials.isNotEmpty) const SizedBox(height: 18),
          if (singleMaterialScope && topHighProviders.isNotEmpty)
            _RankListCard(
              title: 'Contrapartes con precio promedio más alto',
              items: topHighProviders,
              formatter: (value) => formatMoney(value),
            ),
          if (singleMaterialScope && topHighProviders.isNotEmpty)
            const SizedBox(height: 18),
          if (singleMaterialScope && topLowProviders.isNotEmpty)
            _RankListCard(
              title: 'Contrapartes con precio promedio más bajo',
              items: topLowProviders,
              formatter: (value) => formatMoney(value),
            ),
          if (!singleMaterialScope && topHighMaterials.isNotEmpty)
            _RankListCard(
              title: 'Materiales con precio promedio más alto',
              items: topHighMaterials,
              formatter: (value) => formatMoney(value),
            ),
          if (!singleMaterialScope && topHighMaterials.isNotEmpty)
            const SizedBox(height: 18),
          if (!singleMaterialScope && topLowMaterials.isNotEmpty)
            _RankListCard(
              title: 'Materiales con precio promedio más bajo',
              items: topLowMaterials,
              formatter: (value) => formatMoney(value),
            ),
          if (!singleMaterialScope && materialSpreadEntries.isNotEmpty)
            const SizedBox(height: 18),
          if (!singleMaterialScope && materialSpreadEntries.isNotEmpty)
            _RankListCard(
              title: 'Materiales con mayor dispersión',
              items: materialSpreadEntries.take(5).toList(growable: false),
              formatter: (value) => formatMoney(value),
            ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _InsightsSideTrigger extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onTap;

  const _InsightsSideTrigger({required this.isOpen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          bottomLeft: Radius.circular(18),
        ),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              bottomLeft: Radius.circular(18),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.9),
                tokens.badgeBackground.withValues(alpha: 0.96),
              ],
            ),
            border: Border.all(
              color: tokens.primaryStrong.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.primaryStrong.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(-8, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOpen ? Icons.chevron_right_rounded : Icons.analytics_rounded,
                color: tokens.primaryStrong,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isOpen ? 'Ocultar vista rápida' : 'Vista rápida',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
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

class _MaterialSeriesLegend {
  final String label;
  final Color color;

  const _MaterialSeriesLegend({required this.label, required this.color});
}

class _MaterialSeriesGroup {
  final String label;
  final List<double?> values;

  const _MaterialSeriesGroup({required this.label, required this.values});
}

class _MaterialSeriesChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_MaterialSeriesGroup> groups;
  final List<_MaterialSeriesLegend> legends;

  const _MaterialSeriesChartCard({
    required this.title,
    required this.subtitle,
    required this.groups,
    required this.legends,
  });

  String _money(double value) => formatMoney(value);

  List<double> _yTicks(double maxValue) {
    if (maxValue <= 0) return const <double>[0, 1, 2, 3];
    final roughStep = maxValue / 4;
    final magnitude = roughStep == 0 ? 1.0 : (roughStep / 1).abs();
    double step;
    if (magnitude <= 0.25) {
      step = 0.25;
    } else if (magnitude <= 0.5) {
      step = 0.5;
    } else if (magnitude <= 1) {
      step = 1;
    } else if (magnitude <= 2) {
      step = 2;
    } else if (magnitude <= 5) {
      step = 5;
    } else {
      step = (roughStep / 5).ceilToDouble() * 5;
    }
    final top = (maxValue / step).ceil() * step;
    return List<double>.generate(5, (index) => top - (step * index));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final maxValue = groups
        .expand((group) => group.values)
        .whereType<double>()
        .fold<double>(0, (current, value) => value > current ? value : current);
    final yTicks = _yTicks(maxValue);
    final chartTop = yTicks.isEmpty ? maxValue : yTicks.first;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surfaceTint.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.border.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: tokens.badgeText.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: legends
                .map(
                  (legend) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: legend.color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        legend.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: tokens.badgeText,
                        ),
                      ),
                    ],
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 48,
                  child: Column(
                    children: yTicks
                        .map(
                          (tick) => Expanded(
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Text(
                                _money(tick),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: tokens.badgeText.withValues(
                                    alpha: 0.82,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 36),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List<Widget>.generate(yTicks.length, (
                              index,
                            ) {
                              final emphasized = index == yTicks.length - 1;
                              return Container(
                                height: emphasized ? 1.6 : 1,
                                color: emphasized
                                    ? tokens.primaryStrong.withValues(
                                        alpha: 0.35,
                                      )
                                    : tokens.border.withValues(alpha: 0.38),
                              );
                            }),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 36),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: groups
                                .map(
                                  (group) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: List<Widget>.generate(legends.length, (
                                                index,
                                              ) {
                                                final value =
                                                    index < group.values.length
                                                    ? group.values[index]
                                                    : null;
                                                final ratio =
                                                    value == null ||
                                                        chartTop <= 0
                                                    ? 0.0
                                                    : (value / chartTop).clamp(
                                                        0.0,
                                                        1.0,
                                                      );
                                                return Expanded(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 3,
                                                        ),
                                                    child: Tooltip(
                                                      message: value == null
                                                          ? '${legends[index].label} · SIN DATO'
                                                          : '${legends[index].label} · ${_money(value)}',
                                                      child: Align(
                                                        alignment: Alignment
                                                            .bottomCenter,
                                                        child: AnimatedContainer(
                                                          duration:
                                                              const Duration(
                                                                milliseconds:
                                                                    180,
                                                              ),
                                                          curve: Curves
                                                              .easeOutCubic,
                                                          height:
                                                              8 + (188 * ratio),
                                                          decoration: BoxDecoration(
                                                            color: value == null
                                                                ? legends[index]
                                                                      .color
                                                                      .withValues(
                                                                        alpha:
                                                                            0.10,
                                                                      )
                                                                : legends[index]
                                                                      .color,
                                                            borderRadius:
                                                                const BorderRadius.only(
                                                                  topLeft:
                                                                      Radius.circular(
                                                                        4,
                                                                      ),
                                                                  topRight:
                                                                      Radius.circular(
                                                                        4,
                                                                      ),
                                                                ),
                                                            border: Border.all(
                                                              color:
                                                                  value == null
                                                                  ? legends[index]
                                                                        .color
                                                                        .withValues(
                                                                          alpha:
                                                                              0.18,
                                                                        )
                                                                  : legends[index]
                                                                        .color
                                                                        .withValues(
                                                                          alpha:
                                                                              0.92,
                                                                        ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            group.label,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: tokens.badgeText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
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
    );
  }
}

class _HistoryTrendStrip extends StatelessWidget {
  final List<_HistoryTrendPoint> points;

  const _HistoryTrendStrip({required this.points});

  String _money(double value) => formatMoney(value);

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }
    final prices = points.map((point) => point.price).toList(growable: false);
    final minValue = prices.reduce((a, b) => a < b ? a : b);
    final maxValue = prices.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs();
    final paddedMin = range < 0.12
        ? minValue - 0.08
        : minValue - (range * 0.18);
    final paddedMax = range < 0.12
        ? maxValue + 0.08
        : maxValue + (range * 0.18);
    final axisIndices = <int>{
      0,
      if (points.length > 2) (points.length / 2).floor(),
      points.length - 1,
    }.toList()..sort();
    return Container(
      height: 138,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: tokens.surfaceTint.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border.withValues(alpha: 0.68)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Evolución reciente',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Precio por fecha',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: tokens.badgeText.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chartWidth = constraints.maxWidth;
                final chartHeight = constraints.maxHeight - 28;
                double xFor(int index) {
                  if (points.length == 1) return chartWidth / 2;
                  return (chartWidth / (points.length - 1)) * index;
                }

                double yFor(double price) {
                  final normalized =
                      (price - paddedMin) /
                      ((paddedMax - paddedMin).abs() < 0.001
                          ? 1.0
                          : (paddedMax - paddedMin));
                  return chartHeight - (normalized * (chartHeight - 12)) - 6;
                }

                return Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: CustomPaint(
                          painter: _TrendLinePainter(
                            values: prices,
                            color: tokens.primaryStrong,
                            guideColor: tokens.border.withValues(alpha: 0.28),
                            minOverride: paddedMin,
                            maxOverride: paddedMax,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    ...List<Widget>.generate(points.length, (index) {
                      final point = points[index];
                      return Positioned(
                        left: xFor(index) - 16,
                        top: yFor(point.price) - 16,
                        child: Tooltip(
                          message:
                              '${point.label.replaceFirst('\n', ' ')} · ${_money(point.price)}',
                          child: MouseRegion(
                            cursor: SystemMouseCursors.precise,
                            child: Container(
                              width: 32,
                              height: 32,
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                      );
                    }),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Row(
                        children: List<Widget>.generate(points.length, (index) {
                          final showLabel = axisIndices.contains(index);
                          return Expanded(
                            child: Text(
                              showLabel ? points[index].label : '',
                              textAlign: index == 0
                                  ? TextAlign.left
                                  : index == points.length - 1
                                  ? TextAlign.right
                                  : TextAlign.center,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                color: tokens.badgeText.withValues(alpha: 0.82),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryInfoPill extends StatelessWidget {
  final String label;
  final bool highlighted;

  const _HistoryInfoPill({required this.label, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? tokens.primaryStrong.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? tokens.primaryStrong.withValues(alpha: 0.32)
              : tokens.border.withValues(alpha: 0.58),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: highlighted ? tokens.primaryStrong : tokens.badgeText,
        ),
      ),
    );
  }
}

class _HistoryMovementField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _HistoryMovementField({required this.value, required this.onChanged});

  static const _items = <(String, String)>[
    ('todos', 'TODOS'),
    ('altas', 'ALTAS'),
    ('bajas', 'BAJAS'),
    ('sin_cambio', 'SIN CAMBIO'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentLabel = _items
        .firstWhere((item) => item.$1 == value, orElse: () => _items.first)
        .$2;
    return _HistoryCompactPickerField(
      label: 'Movimiento',
      value: currentLabel,
      items: _items.map((item) => item.$2).toList(growable: false),
      onChanged: (label) {
        final mapped = _items.firstWhere(
          (item) => item.$2 == label,
          orElse: () => _items.first,
        );
        onChanged(mapped.$1);
      },
    );
  }
}

class _HistoryCompactPickerField extends StatefulWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _HistoryCompactPickerField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_HistoryCompactPickerField> createState() =>
      _HistoryCompactPickerFieldState();
}

class _HistoryCompactPickerFieldState
    extends State<_HistoryCompactPickerField> {
  Future<void> _openPicker() async {
    final selected = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AreaThemeScope(
          tokens: menudeoAreaTokens,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            child: ContractPopupSurface(
              constraints: const BoxConstraints(maxWidth: 280, maxHeight: 320),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtro: ${widget.label.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: menudeoAreaTokens.primaryStrong,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: widget.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final item = widget.items[index];
                        return _AdjustmentPickerOption(
                          label: item,
                          selected: widget.value == item,
                          onTap: () => Navigator.of(dialogContext).pop(item),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      style: contractSecondaryButtonStyle(dialogContext),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || selected == null || selected == widget.value) return;
    widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            widget.label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: tokens.badgeText,
              letterSpacing: 0.4,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openPicker,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.border.withValues(alpha: 0.78)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.filter_alt_rounded,
                  size: 18,
                  color: tokens.primaryStrong,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: tokens.primaryStrong,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 22,
                  color: tokens.primaryStrong,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryDateRangeField extends StatelessWidget {
  final DateTimeRange? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _HistoryDateRangeField({
    required this.value,
    required this.onTap,
    this.onClear,
  });

  String _format(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = date.year.toString();
    return '$dd/$mm/$yy';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'FECHA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: tokens.badgeText,
                letterSpacing: 0.4,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: tokens.border.withValues(alpha: 0.78),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: tokens.primaryStrong,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      value == null
                          ? 'FECHA'
                          : '${_format(value!.start)} - ${_format(value!.end)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: value == null
                            ? tokens.badgeText.withValues(alpha: 0.72)
                            : tokens.primaryStrong,
                      ),
                    ),
                  ),
                  if (value != null && onClear != null)
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: onClear,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: tokens.badgeText,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 22,
                      color: tokens.primaryStrong,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankListCard extends StatelessWidget {
  final String title;
  final List<MapEntry<String, double>> items;
  final String Function(double value) formatter;

  const _RankListCard({
    required this.title,
    required this.items,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final maxValue = items.isEmpty
        ? 1.0
        : items.map((item) => item.value).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surfaceTint.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.border.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final ratio = maxValue <= 0 ? 0.0 : item.value / maxValue;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RankRow(
                label: item.key,
                value: formatter(item.value),
                ratio: ratio,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MovementListCard extends StatelessWidget {
  final String title;
  final List<MapEntry<String, int>> items;
  final int upMoves;
  final int downMoves;

  const _MovementListCard({
    required this.title,
    required this.items,
    required this.upMoves,
    required this.downMoves,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final maxValue = items.isEmpty
        ? 1
        : items.map((item) => item.value).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surfaceTint.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.border.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniStatCard(label: 'Altas', value: '$upMoves'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatCard(
                  label: 'Bajas',
                  value: '$downMoves',
                  highlighted: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final ratio = maxValue <= 0 ? 0.0 : item.value / maxValue;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RankRow(
                label: item.key,
                value: '${item.value}',
                ratio: ratio,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final String label;
  final String value;
  final double ratio;

  const _RankRow({
    required this.label,
    required this.value,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: tokens.badgeText,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: ratio.clamp(0, 1),
            backgroundColor: tokens.surfaceTint.withValues(alpha: 0.82),
            valueColor: AlwaysStoppedAnimation<Color>(tokens.primaryStrong),
          ),
        ),
      ],
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final Color guideColor;
  final double? minOverride;
  final double? maxOverride;

  const _TrendLinePainter({
    required this.values,
    required this.color,
    required this.guideColor,
    this.minOverride,
    this.maxOverride,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = maxOverride ?? values.reduce((a, b) => a > b ? a : b);
    final minValue = minOverride ?? values.reduce((a, b) => a < b ? a : b);
    final range = (maxValue - minValue).abs() < 0.001
        ? 1.0
        : maxValue - minValue;
    final chartHeight = size.height - 8;
    final chartWidth = size.width;

    final guidePaint = Paint()
      ..color = guideColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = (chartHeight / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), guidePaint);
    }

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.18), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, chartWidth, chartHeight));

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < values.length; i++) {
      final dx = values.length == 1
          ? chartWidth / 2
          : (chartWidth / (values.length - 1)) * i;
      final normalized = (values[i] - minValue) / range;
      final dy = chartHeight - (normalized * (chartHeight - 12)) - 6;
      if (i == 0) {
        path.moveTo(dx, dy);
        fillPath.moveTo(dx, chartHeight);
        fillPath.lineTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
        fillPath.lineTo(dx, dy);
      }
    }
    fillPath.lineTo(chartWidth, chartHeight);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final pointPaint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final dx = values.length == 1
          ? chartWidth / 2
          : (chartWidth / (values.length - 1)) * i;
      final normalized = (values[i] - minValue) / range;
      final dy = chartHeight - (normalized * (chartHeight - 12)) - 6;
      canvas.drawCircle(Offset(dx, dy), 4.2, pointPaint);
      canvas.drawCircle(
        Offset(dx, dy),
        7,
        Paint()..color = color.withValues(alpha: 0.16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.guideColor != guideColor ||
        oldDelegate.minOverride != minOverride ||
        oldDelegate.maxOverride != maxOverride;
  }
}

class _PriceAdjustSidePanel extends StatelessWidget {
  final ValueChanged<String> onNavigate;

  const _PriceAdjustSidePanel({required this.onNavigate});

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
                'Menudeo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              const _PriceAdjustSectionHeader(label: 'MENU'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x66EFD7C2),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: tokens.primaryStrong.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  children: [
                    _PriceAdjustPanelItem(
                      icon: Icons.receipt_long_rounded,
                      title: 'Compras',
                      subtitle: 'Tickets virtuales de compra',
                      onTapSync: () => onNavigate('Tickets de menudeo'),
                    ),
                    const SizedBox(height: 8),
                    _PriceAdjustPanelItem(
                      icon: Icons.point_of_sale_rounded,
                      title: 'Ventas',
                      subtitle: 'Tickets virtuales de venta',
                      onTapSync: () => onNavigate('Ventas menudeo'),
                    ),
                    const SizedBox(height: 8),
                    _PriceAdjustPanelItem(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Depósitos y gastos',
                      subtitle: 'Vouchers de caja y egresos',
                      onTapSync: () => onNavigate('Depósitos y gastos'),
                    ),
                    const SizedBox(height: 8),
                    _PriceAdjustPanelItem(
                      icon: Icons.auto_graph_rounded,
                      title: 'Ajuste de precios',
                      subtitle: 'Cambios e historial',
                      isActive: true,
                      onTapSync: () => onNavigate('Ajuste de precios'),
                    ),
                    const SizedBox(height: 8),
                    _PriceAdjustPanelItem(
                      icon: Icons.price_check_rounded,
                      title: 'Catálogo',
                      subtitle: 'Materiales, grupos y precios',
                      onTapSync: () => onNavigate('Catálogo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _PriceAdjustSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              _PriceAdjustPanelItem(
                icon: Icons.space_dashboard_rounded,
                title: 'Dashboard Menudeo',
                subtitle: 'Vista general del área',
                isAccent: true,
                onTapSync: () => onNavigate('Dashboard Menudeo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceAdjustSectionHeader extends StatelessWidget {
  final String label;

  const _PriceAdjustSectionHeader({required this.label});

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

class _PriceAdjustPanelItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isActive;
  final bool isAccent;
  final VoidCallback onTapSync;

  const _PriceAdjustPanelItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTapSync,
    this.isActive = false,
    this.isAccent = false,
  });

  @override
  State<_PriceAdjustPanelItem> createState() => _PriceAdjustPanelItemState();
}

class _PriceAdjustPanelItemState extends State<_PriceAdjustPanelItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final active = widget.isActive;
    final hasSubtitle =
        widget.subtitle != null && widget.subtitle!.trim().isNotEmpty;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: _hovered ? 1.012 : 1,
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTapSync,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: widget.isAccent
                    ? const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFFE5A56F), Color(0xFFCF7E59)],
                      )
                    : active
                    ? const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFFEFC186), Color(0xFFDFA06F)],
                      )
                    : const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFFF6E2D1), Color(0xFFE7B992)],
                      ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.isAccent
                      ? const Color(0xFFF7DCC5)
                      : active
                      ? tokens.primaryStrong.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: _hovered ? 0.62 : 0.58),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isAccent
                        ? const Color(0xFFB46D4F).withValues(alpha: 0.22)
                        : active
                        ? const Color(0xFFB97A5C).withValues(alpha: 0.18)
                        : const Color(
                            0xFFB97A5C,
                          ).withValues(alpha: _hovered ? 0.14 : 0.12),
                    blurRadius: widget.isAccent ? 22 : (_hovered ? 18 : 16),
                    offset: Offset(0, widget.isAccent ? 12 : 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.icon, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: widget.isAccent
                                ? Colors.white
                                : tokens.primaryStrong,
                          ),
                        ),
                        if (hasSubtitle) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: widget.isAccent
                                  ? Colors.white.withValues(alpha: 0.92)
                                  : tokens.badgeText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (active && !widget.isAccent) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check_circle_rounded,
                      color: tokens.primarySoft,
                      size: 22,
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: widget.isAccent
                          ? Colors.white
                          : tokens.primaryStrong,
                      size: 22,
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

class _PriceAdjustHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _PriceAdjustHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_PriceAdjustHeaderButton> createState() =>
      _PriceAdjustHeaderButtonState();
}

class _PriceAdjustHeaderButtonState extends State<_PriceAdjustHeaderButton> {
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
        curve: Curves.easeOutCubic,
        scale: highlighted ? 1.026 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
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
              curve: Curves.easeOutCubic,
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
                  BoxShadow(
                    blurRadius: highlighted ? 20 : 10,
                    color: tokens.primaryStrong.withValues(
                      alpha: highlighted ? 0.10 : 0.04,
                    ),
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

class _PriceAdjustBrand extends StatelessWidget {
  final Animation<double> contentAnim;
  final String title;

  const _PriceAdjustBrand({required this.contentAnim, required this.title});

  @override
  Widget build(BuildContext context) {
    return MenudeoHeaderBrand(contentAnim: contentAnim, title: title);
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool highlighted;

  const _MiniStatCard({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted
            ? tokens.primaryStrong.withValues(alpha: 0.10)
            : tokens.surfaceTint.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted
              ? tokens.primaryStrong.withValues(alpha: 0.30)
              : tokens.border.withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: tokens.badgeText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: highlighted
                  ? tokens.primaryStrong
                  : const Color(0xFF1F262B),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustmentSectionTitle extends StatelessWidget {
  final String text;

  const _AdjustmentSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: tokens.primaryStrong,
      ),
    );
  }
}

class _AdjustmentTag extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AdjustmentTag({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? tokens.primaryStrong.withValues(alpha: 0.14)
              : tokens.surfaceTint.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? tokens.primaryStrong.withValues(alpha: 0.36)
                : tokens.border.withValues(alpha: 0.76),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: tokens.primaryStrong,
          ),
        ),
      ),
    );
  }
}

class _AdjustmentModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  const _AdjustmentModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active
              ? tokens.primaryStrong.withValues(alpha: 0.12)
              : tokens.surfaceTint.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active
                ? tokens.primaryStrong.withValues(alpha: 0.34)
                : tokens.border.withValues(alpha: 0.76),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tokens.primaryStrong),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: tokens.primaryStrong,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tokens.badgeText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustmentFilterField extends StatefulWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _AdjustmentFilterField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_AdjustmentFilterField> createState() => _AdjustmentFilterFieldState();
}

class _AdjustmentFilterFieldState extends State<_AdjustmentFilterField> {
  Future<void> _openPicker() async {
    final searchC = TextEditingController();
    String query = '';
    final selected = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AreaThemeScope(
          tokens: menudeoAreaTokens,
          child: StatefulBuilder(
            builder: (context, setLocalState) {
              final filtered = widget.items
                  .where((item) => item.contains(query.toUpperCase()))
                  .toList(growable: false);
              final tokens = AreaThemeScope.of(context);
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 24,
                ),
                child: ContractPopupSurface(
                  constraints: const BoxConstraints(
                    maxWidth: 380,
                    maxHeight: 460,
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filtro: ${widget.label.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: tokens.primaryStrong,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: searchC,
                        decoration: _adjustmentFieldDecoration(
                          context,
                          hintText: 'Buscar',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                          ),
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: tokens.primaryStrong,
                        ),
                        onChanged: (value) => setLocalState(() {
                          query = value.trim().toUpperCase();
                        }),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            if (index == 0) {
                              return _AdjustmentPickerOption(
                                label: 'TODOS',
                                selected: widget.value == null,
                                onTap: () =>
                                    Navigator.of(dialogContext).pop(null),
                              );
                            }
                            final item = filtered[index - 1];
                            return _AdjustmentPickerOption(
                              label: item,
                              selected: widget.value == item,
                              onTap: () =>
                                  Navigator.of(dialogContext).pop(item),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: contractSecondaryButtonStyle(dialogContext),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: contractSecondaryButtonStyle(dialogContext),
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(null),
                            child: const Text('Limpiar'),
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
    searchC.dispose();
    if (!mounted) return;
    if (selected != widget.value) {
      widget.onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            widget.label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: tokens.badgeText,
              letterSpacing: 0.4,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openPicker,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.border.withValues(alpha: 0.78)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.filter_alt_rounded,
                  size: 18,
                  color: tokens.primaryStrong,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.value ?? 'TODOS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: widget.value == null
                          ? tokens.badgeText.withValues(alpha: 0.72)
                          : tokens.primaryStrong,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: tokens.primaryStrong,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AdjustmentPickerOption extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AdjustmentPickerOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_AdjustmentPickerOption> createState() =>
      _AdjustmentPickerOptionState();
}

class _AdjustmentPickerOptionState extends State<_AdjustmentPickerOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: widget.selected
                  ? tokens.primaryStrong.withValues(alpha: 0.12)
                  : tokens.surfaceTint.withValues(alpha: _hovered ? 0.9 : 0.76),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.selected
                    ? tokens.primaryStrong.withValues(alpha: 0.36)
                    : tokens.border.withValues(alpha: 0.72),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: tokens.primaryStrong,
                    ),
                  ),
                ),
                if (widget.selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: tokens.primaryStrong,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdjustmentMiniPill extends StatelessWidget {
  final String label;
  final bool highlighted;

  const _AdjustmentMiniPill({required this.label, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? tokens.primaryStrong.withValues(alpha: 0.12)
            : tokens.badgeBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? tokens.primaryStrong.withValues(alpha: 0.30)
              : tokens.border.withValues(alpha: 0.7),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: tokens.primaryStrong,
        ),
      ),
    );
  }
}

class _AdjustmentPriceChip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlighted;

  const _AdjustmentPriceChip({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? tokens.primaryStrong.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted
              ? tokens.primaryStrong.withValues(alpha: 0.34)
              : tokens.border.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: tokens.badgeText.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: highlighted
                  ? tokens.primaryStrong
                  : const Color(0xFF1F262B),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustmentPreviewSurface extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> selectedRows;
  final String adjustmentMode;
  final String adjustmentValueText;
  final String Function(num value) formatMoney;
  final String Function(String mode) modeLabel;
  final double Function(double current) computeNewPrice;

  const _AdjustmentPreviewSurface({
    required this.loading,
    required this.error,
    required this.rows,
    required this.selectedRows,
    required this.adjustmentMode,
    required this.adjustmentValueText,
    required this.formatMoney,
    required this.modeLabel,
    required this.computeNewPrice,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final sample = selectedRows.isNotEmpty ? selectedRows.first : null;
    final sampleCurrent = sample == null
        ? null
        : ((sample['final_price'] ?? 0) as num).toDouble();
    final sampleNext = sampleCurrent == null
        ? null
        : computeNewPrice(sampleCurrent);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceTint.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.border.withValues(alpha: 0.76)),
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Text(error!, style: const TextStyle(fontWeight: FontWeight.w700))
          : rows.isEmpty
          ? const Text('No hay datos visibles para calcular la vista previa.')
          : Column(
              children: [
                _AdjustmentPreviewRow(
                  label: 'Precios visibles / seleccionados',
                  value: '${rows.length} / ${selectedRows.length}',
                ),
                const SizedBox(height: 10),
                _AdjustmentPreviewRow(
                  label: 'Cambio aplicado',
                  value:
                      '${modeLabel(adjustmentMode)}${adjustmentValueText.trim().isEmpty ? '' : ' · $adjustmentValueText'}',
                ),
                const SizedBox(height: 10),
                _AdjustmentPreviewRow(
                  label: 'Precio actual',
                  value: sampleCurrent == null
                      ? 'Selecciona una fila'
                      : formatMoney(sampleCurrent),
                ),
                const SizedBox(height: 10),
                _AdjustmentPreviewRow(
                  label: 'Precio final',
                  value: sampleNext == null
                      ? 'Sin vista previa'
                      : formatMoney(sampleNext),
                  emphasized: true,
                ),
              ],
            ),
    );
  }
}

class _AdjustmentPreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _AdjustmentPreviewRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tokens.badgeText,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasized ? 18 : 14,
            fontWeight: FontWeight.w900,
            color: emphasized ? tokens.primaryStrong : const Color(0xFF1F262B),
          ),
        ),
      ],
    );
  }
}

class _InsightStatStrip extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _InsightStatStrip({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surfaceTint.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: tokens.badgeText,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceMiniSummary extends StatelessWidget {
  final double minPrice;
  final double maxPrice;
  final double averagePrice;
  final int counterpartyCount;
  final int materialCount;
  final bool showAverage;
  final double spreadValue;

  const _PriceMiniSummary({
    required this.minPrice,
    required this.maxPrice,
    required this.averagePrice,
    required this.counterpartyCount,
    required this.materialCount,
    required this.showAverage,
    required this.spreadValue,
  });

  String _money(double value) => formatMoney(value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(label: 'Mínimo', value: _money(minPrice)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            label: showAverage ? 'Promedio' : 'Dispersión',
            value: showAverage ? _money(averagePrice) : _money(spreadValue),
            highlighted: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            label: showAverage ? 'Máximo' : 'Materiales / contrapartes',
            value: showAverage
                ? _money(maxPrice)
                : '$materialCount / $counterpartyCount',
          ),
        ),
      ],
    );
  }
}

class _MenudeoPriceAdjustmentsBackground extends StatelessWidget {
  const _MenudeoPriceAdjustmentsBackground();

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
          child: _blurCircle(
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
          child: _blurCircle(
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
          child: _blurCircle(
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

  Widget _blurCircle(double size, Gradient gradient) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
      ),
    );
  }
}
