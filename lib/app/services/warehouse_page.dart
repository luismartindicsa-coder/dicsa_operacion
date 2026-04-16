import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart'
    show kPrimaryMouseButton, kSecondaryMouseButton;
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
import '../shared/ui_contract_core/dialogs/confirm_dialog_key_handler.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/utils/number_formatters.dart';
import 'inventory_page.dart';
import 'services_page.dart';
import 'services_shell.dart';
import 'weighings_page.dart';

const List<String> _kWarehouseCategories = <String>[
  'herramienta',
  'uniforme',
  'material',
  'consumible',
  'refaccion',
];

const List<String> _kWarehouseMovementTypes = <String>[
  'apertura',
  'entrada',
  'salida',
  'ajuste',
  'cierre',
];

const List<String> _kWarehouseCutStatuses = <String>[
  'abierto',
  'en_revision',
  'cerrado',
];

const double _kWarehouseInventoryActionsW = 42;
const double _kWarehouseCutLinesActionsW = 42;

class WarehousePage extends StatefulWidget {
  const WarehousePage({super.key});

  @override
  State<WarehousePage> createState() => _WarehousePageState();
}

class _WarehousePageState extends State<WarehousePage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final SupabaseClient _supa = Supabase.instance.client;

  late final TabController _tabs = TabController(length: 5, vsync: this);

  bool _loading = true;
  bool _refreshing = false;
  bool _saving = false;
  bool _pendingAutoReload = false;

  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _movements = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _cuts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _cutLines = <Map<String, dynamic>>[];

  String _search = '';
  String? _categoryFilter;
  String? _locationFilter;
  String? _stockStateFilter;
  String? _selectedCutId;
  String? _selectedInventoryRowId;
  String? _selectedMovementRowId;
  final Set<String> _selectedMovementIds = <String>{};
  bool _movementDragSelecting = false;
  bool _suppressNextMovementTapSelection = false;
  String? _movementDragAnchorRowId;
  Set<String> _movementDragBaseSelection = <String>{};
  String? _selectedCutLineRowId;
  String? _hoveredInventoryRowId;
  String? _hoveredMovementRowId;
  String? _hoveredCutLineRowId;
  final FocusNode _movementsFocusNode = FocusNode(
    debugLabel: 'warehouse_movements_focus',
  );

  Timer? _autoRefreshTimer;
  Timer? _deferredAutoRefreshTimer;
  RealtimeChannel? _realtime;
  DateTime? _lastBackgroundRefreshAt;
  static const Duration _backgroundRefreshMinGap = Duration(seconds: 12);
  static const Duration _backgroundRefreshRetryDelay = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadAll(showLoader: true));
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabs.dispose();
    _movementsFocusNode.dispose();
    _autoRefreshTimer?.cancel();
    _deferredAutoRefreshTimer?.cancel();
    _realtime?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestAutoReload(force: true);
    }
  }

  void _setupAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) => _requestAutoReload(),
    );

    _realtime?.unsubscribe();
    _realtime = _supa
        .channel('warehouse-auto-refresh')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_items',
          callback: (_) => _requestAutoReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_movements',
          callback: (_) => _requestAutoReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_monthly_cuts',
          callback: (_) => _requestAutoReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_monthly_cut_lines',
          callback: (_) {
            _requestAutoReload();
          },
        )
        .subscribe();
  }

  bool get _shouldDeferBackgroundRefresh => _saving || _isEditableTextFocused();

  void _queueDeferredAutoReload([Duration? delay]) {
    if (!mounted) return;
    _pendingAutoReload = true;
    _deferredAutoRefreshTimer?.cancel();
    _deferredAutoRefreshTimer = Timer(
      delay ?? _backgroundRefreshRetryDelay,
      () {
        _deferredAutoRefreshTimer = null;
        _requestAutoReload();
      },
    );
  }

  void _requestAutoReload({bool force = false}) {
    if (!mounted) return;
    if (!force && (_refreshing || _loading || _shouldDeferBackgroundRefresh)) {
      _queueDeferredAutoReload();
      return;
    }
    if (!force && _lastBackgroundRefreshAt != null) {
      final elapsed = DateTime.now().difference(_lastBackgroundRefreshAt!);
      if (elapsed < _backgroundRefreshMinGap) {
        _queueDeferredAutoReload(_backgroundRefreshMinGap - elapsed);
        return;
      }
    }
    if (_refreshing) {
      _queueDeferredAutoReload();
      return;
    }
    unawaited(_refreshSilentlyIfIdle(force: force));
  }

  Future<void> _refreshSilentlyIfIdle({bool force = false}) async {
    if (!mounted || _refreshing) return;
    try {
      await _loadAll(showLoader: false);
      _lastBackgroundRefreshAt = DateTime.now();
    } finally {
      if (_pendingAutoReload && mounted) {
        if (force || !_shouldDeferBackgroundRefresh) {
          _pendingAutoReload = false;
          _requestAutoReload();
        } else {
          _queueDeferredAutoReload();
        }
      }
    }
  }

  Future<void> _loadAll({required bool showLoader}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (showLoader && mounted) {
      setState(() => _loading = true);
    }

    try {
      final items = await _supa
          .from('inventory_items')
          .select()
          .order('name', ascending: true);
      final movements = await _supa
          .from('inventory_movements')
          .select('*, inventory_items(name,code)')
          .order('created_at', ascending: false)
          .limit(300);
      final cuts = await _supa
          .from('inventory_monthly_cuts')
          .select()
          .order('period_month', ascending: false)
          .order('year', ascending: false)
          .order('month', ascending: false)
          .limit(24);

      final nextItems = (items as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final nextMovements = (movements as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final nextCuts = (cuts as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      String? nextSelectedCutId = _selectedCutId;
      if (nextCuts.isNotEmpty) {
        final hasSelected =
            nextSelectedCutId != null &&
            nextCuts.any(
              (c) => (c['id'] ?? '').toString() == nextSelectedCutId,
            );
        if (!hasSelected) {
          final openCut = nextCuts.cast<Map<String, dynamic>>().firstWhere(
            (c) => (c['status'] ?? '').toString() == 'abierto',
            orElse: () => nextCuts.first,
          );
          nextSelectedCutId = (openCut['id'] ?? '').toString();
        }
      } else {
        nextSelectedCutId = null;
      }

      if (!mounted) return;
      setState(() {
        _items = nextItems;
        _movements = nextMovements;
        _cuts = nextCuts;
        _selectedCutId = nextSelectedCutId;
        _selectedMovementIds.removeWhere(
          (id) => !_movements.any((r) => (r['id'] ?? '').toString() == id),
        );
        if (_selectedMovementRowId != null &&
            !_movements.any(
              (r) => (r['id'] ?? '').toString() == _selectedMovementRowId,
            )) {
          _selectedMovementRowId = null;
        }
      });

      if (nextSelectedCutId != null) {
        await _loadCutLines(nextSelectedCutId);
      } else if (mounted) {
        setState(() => _cutLines = <Map<String, dynamic>>[]);
      }
    } catch (e) {
      _toast('No se pudo cargar almacen: $e');
    } finally {
      _refreshing = false;
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadCutLines(String cutId) async {
    try {
      final rows = await _supa
          .from('inventory_monthly_cut_lines')
          .select('*, inventory_items(name,code)')
          .eq('cut_id', cutId)
          .order('created_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _cutLines = (rows as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (e) {
      _toast('No se pudo cargar lineas de corte: $e');
    }
  }

  int get _activeItemsCount =>
      _items.where((e) => (e['is_active'] as bool?) ?? true).length;

  List<Map<String, dynamic>> get _lowStockItems {
    return _items.where((e) {
      final current = _toNum(e['current_stock']) ?? 0;
      final minimum = _toNum(e['minimum_stock']) ?? 0;
      return current <= minimum;
    }).toList();
  }

  int get _monthMovementsCount {
    final now = DateTime.now();
    return _movements.where((row) {
      final dt = _dateFromAny(row['created_at']);
      return dt != null && dt.year == now.year && dt.month == now.month;
    }).length;
  }

  int get _monthAdjustmentsCount {
    final now = DateTime.now();
    return _movements.where((row) {
      final dt = _dateFromAny(row['created_at']);
      return dt != null &&
          dt.year == now.year &&
          dt.month == now.month &&
          (row['movement_type'] ?? '').toString() == 'ajuste';
    }).length;
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _items.where((row) {
      if (_search.trim().isNotEmpty) {
        final q = _search.trim().toLowerCase();
        final code = (row['code'] ?? '').toString().toLowerCase();
        final name = (row['name'] ?? '').toString().toLowerCase();
        final description = (row['description'] ?? '').toString().toLowerCase();
        if (!code.contains(q) &&
            !name.contains(q) &&
            !description.contains(q)) {
          return false;
        }
      }

      if (_categoryFilter != null &&
          (row['category'] ?? '').toString() != _categoryFilter) {
        return false;
      }

      if (_locationFilter != null &&
          (row['location'] ?? '').toString() != _locationFilter) {
        return false;
      }

      if (_stockStateFilter != null) {
        final state = _stockState(row);
        if (state != _stockStateFilter) return false;
      }

      return true;
    }).toList();
  }

  List<String> get _locationOptions {
    final set =
        _items
            .map((e) => (e['location'] ?? '').toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
          ..toList().sort();
    final list = set.toList()..sort();
    return list;
  }

  String _stockState(Map<String, dynamic> row) {
    final current = _toNum(row['current_stock']) ?? 0;
    final minimum = _toNum(row['minimum_stock']) ?? 0;
    if (current <= 0) return 'sin_existencia';
    if (current <= minimum) return 'bajo_stock';
    return 'ok';
  }

  Color _stockStateColor(String state) {
    switch (state) {
      case 'sin_existencia':
        return const Color(0xFFC62828);
      case 'bajo_stock':
        return const Color(0xFFEF6C00);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  String _stockStateLabel(String state) {
    switch (state) {
      case 'sin_existencia':
        return 'Sin existencias';
      case 'bajo_stock':
        return 'Bajo stock';
      default:
        return 'OK';
    }
  }

  Future<void> _createItem() async {
    final codeC = TextEditingController();
    final nameC = TextEditingController();
    final descC = TextEditingController();
    final unitC = TextEditingController(text: 'piezas');
    final minC = TextEditingController(text: '0');
    final locC = TextEditingController();
    String category = _kWarehouseCategories.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            title: const Text('Nuevo articulo'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeC,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Codigo *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameC,
                    decoration: const InputDecoration(labelText: 'Nombre *'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    items: _kWarehouseCategories
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(_labelCategory(e)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setLocalState(() => category = v);
                    },
                    decoration: const InputDecoration(labelText: 'Categoria *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: unitC,
                    decoration: const InputDecoration(labelText: 'Unidad *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: minC,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Stock minimo *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: locC,
                    decoration: const InputDecoration(labelText: 'Ubicacion *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descC,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descripcion (opcional)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final code = codeC.text.trim().toUpperCase();
    final name = nameC.text.trim();
    final unit = unitC.text.trim();
    final min = double.tryParse(minC.text.trim());
    final location = locC.text.trim();

    if (code.isEmpty ||
        name.isEmpty ||
        unit.isEmpty ||
        min == null ||
        location.isEmpty) {
      _toast('Completa los campos obligatorios del articulo.');
      return;
    }

    await _guardedSave(() async {
      await _supa.from('inventory_items').insert({
        'code': code,
        'name': name,
        'category': category,
        'description': descC.text.trim().isEmpty ? null : descC.text.trim(),
        'unit': unit,
        'minimum_stock': min,
        'location': location,
        'current_stock': 0,
        'is_active': true,
      });
      await _loadAll(showLoader: false);
      _toast('Articulo creado.');
    });
  }

  Future<void> _registerMovement() async {
    if (_items.isEmpty) {
      _toast('Primero registra al menos un articulo.');
      return;
    }

    String selectedItemId = (_items.first['id'] ?? '').toString();
    String movementType = 'entrada';
    final qtyC = TextEditingController();
    final areaC = TextEditingController();
    final responsibleC = TextEditingController();
    final reasonC = TextEditingController();
    final refC = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          Map<String, dynamic>? selectedItem;
          for (final item in _items) {
            if ((item['id'] ?? '').toString() == selectedItemId) {
              selectedItem = item;
              break;
            }
          }
          selectedItem ??= _items.first;
          final stock = _toNum(selectedItem['current_stock']) ?? 0;
          final minimum = _toNum(selectedItem['minimum_stock']) ?? 0;
          final location = (selectedItem['location'] ?? '').toString();
          final qty = double.tryParse(qtyC.text.trim()) ?? 0;
          final stockAfter = movementType == 'salida'
              ? stock - qty
              : stock + qty;

          return AlertDialog(
            title: const Text('Registrar movimiento'),
            content: SizedBox(
              width: 580,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedItemId,
                    items: _items
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: (e['id'] ?? '').toString(),
                            child: Text(
                              '${e['code'] ?? '-'} - ${e['name'] ?? '-'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setLocalState(() => selectedItemId = v);
                    },
                    decoration: const InputDecoration(labelText: 'Articulo *'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Stock actual: ${_fmtQty(stock)} | Minimo: ${_fmtQty(minimum)} | Ubicacion: $location',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: movementType,
                    items: _kWarehouseMovementTypes
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(_labelMovementType(e)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setLocalState(() => movementType = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Tipo movimiento *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: qtyC,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
                    ],
                    onChanged: (_) => setLocalState(() {}),
                    decoration: const InputDecoration(labelText: 'Cantidad *'),
                  ),
                  const SizedBox(height: 8),
                  if (qty > 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Stock despues del movimiento: ${_fmtQty(stockAfter)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: stockAfter < 0
                              ? const Color(0xFFC62828)
                              : const Color(0xFF1B5E20),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: areaC,
                    decoration: const InputDecoration(labelText: 'Area'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: responsibleC,
                    decoration: const InputDecoration(
                      labelText: 'Responsable *',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonC,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Motivo *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: refC,
                    decoration: const InputDecoration(
                      labelText: 'Referencia (opcional)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Registrar'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final quantity = double.tryParse(qtyC.text.trim());
    if (quantity == null || quantity <= 0) {
      _toast('La cantidad debe ser mayor a cero.');
      return;
    }

    final selectedItem = _items.firstWhere(
      (item) => (item['id'] ?? '').toString() == selectedItemId,
      orElse: () => <String, dynamic>{},
    );
    final currentStock = _toNum(selectedItem['current_stock']) ?? 0;
    if (movementType == 'salida' && quantity > currentStock) {
      _toast('No se permite salida mayor al stock actual.');
      return;
    }

    final responsible = responsibleC.text.trim();
    final reason = reasonC.text.trim();
    if (responsible.isEmpty || reason.isEmpty) {
      _toast('Responsable y motivo son obligatorios.');
      return;
    }

    await _guardedSave(() async {
      final userId = _supa.auth.currentUser?.id;
      await _supa.from('inventory_movements').insert({
        'item_id': selectedItemId,
        'movement_type': movementType,
        'quantity': quantity,
        'area': areaC.text.trim().isEmpty ? null : areaC.text.trim(),
        'responsible_name': responsible,
        'reason': reason,
        'reference': refC.text.trim().isEmpty ? null : refC.text.trim(),
        'created_by': userId,
      });
      await _loadAll(showLoader: false);
      _toast('Movimiento registrado.');
    });
  }

  Future<void> _openMonthlyCut() async {
    final now = DateTime.now();
    final monthC = TextEditingController(text: now.month.toString());
    final yearC = TextEditingController(text: now.year.toString());
    String status = 'abierto';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            title: const Text('Abrir corte mensual'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: monthC,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Mes *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: yearC,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Año *'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: _kWarehouseCutStatuses
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e,
                            child: Text(_labelCutStatus(e)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setLocalState(() => status = v);
                    },
                    decoration: const InputDecoration(labelText: 'Estado *'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Crear corte'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final month = int.tryParse(monthC.text.trim());
    final year = int.tryParse(yearC.text.trim());
    if (month == null ||
        month < 1 ||
        month > 12 ||
        year == null ||
        year < 2020) {
      _toast('Mes o año invalido.');
      return;
    }

    await _guardedSave(() async {
      final userId = _supa.auth.currentUser?.id;
      final periodMonth = DateTime(year, month, 1);
      final existingCutId = await _findExistingCutIdForPeriod(
        year: year,
        month: month,
      );
      final String cutId;
      if (existingCutId != null) {
        cutId = existingCutId;
      } else {
        final created = await _supa
            .from('inventory_monthly_cuts')
            .insert({
              'period_month': periodMonth.toIso8601String(),
              'month': month,
              'year': year,
              'status': status,
              'opened_at': DateTime.now().toIso8601String(),
              'opened_by': userId,
            })
            .select('id')
            .single();
        cutId = (created['id'] ?? '').toString();
      }

      if (cutId.isNotEmpty) {
        await _ensureCutLines(cutId);
      }
      await _loadAll(showLoader: false);
      if (mounted) {
        setState(() => _selectedCutId = cutId);
      }
      _toast(
        existingCutId == null
            ? 'Corte mensual creado.'
            : 'Ese periodo ya existia. Se abrio el corte existente.',
      );
    });
  }

  Future<String?> _findExistingCutIdForPeriod({
    required int year,
    required int month,
  }) async {
    for (final cut in _cuts) {
      final id = (cut['id'] ?? '').toString();
      if (id.isEmpty) continue;

      final cutMonth = int.tryParse((cut['month'] ?? '').toString());
      final cutYear = int.tryParse((cut['year'] ?? '').toString());
      if (cutMonth == month && cutYear == year) {
        return id;
      }

      final period = _dateFromAny(cut['period_month']);
      if (period != null && period.month == month && period.year == year) {
        return id;
      }
    }

    final byColumns = await _supa
        .from('inventory_monthly_cuts')
        .select('id')
        .eq('month', month)
        .eq('year', year)
        .limit(1);
    if (byColumns.isNotEmpty) {
      final id = (byColumns.first['id'] ?? '').toString();
      if (id.isNotEmpty) return id;
    }

    final from = DateTime(year, month, 1);
    final to = DateTime(year, month + 1, 1);
    final byPeriod = await _supa
        .from('inventory_monthly_cuts')
        .select('id')
        .gte('period_month', from.toIso8601String())
        .lt('period_month', to.toIso8601String())
        .limit(1);
    if (byPeriod.isNotEmpty) {
      final id = (byPeriod.first['id'] ?? '').toString();
      if (id.isNotEmpty) return id;
    }

    return null;
  }

  Future<void> _ensureCutLines(String cutId) async {
    if (_items.isEmpty) return;
    final existing = await _supa
        .from('inventory_monthly_cut_lines')
        .select('item_id')
        .eq('cut_id', cutId);
    final existingItemIds = (existing as List)
        .map((e) => (e['item_id'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toSet();

    final missing = _items.where((item) {
      final itemId = (item['id'] ?? '').toString();
      return itemId.isNotEmpty && !existingItemIds.contains(itemId);
    }).toList();

    if (missing.isEmpty) return;

    final lines = missing
        .map(
          (item) => {
            'cut_id': cutId,
            'item_id': item['id'],
            'system_stock': _toNum(item['current_stock']) ?? 0,
            'physical_stock': _toNum(item['current_stock']) ?? 0,
            'difference': 0,
            'adjustment_applied': false,
          },
        )
        .toList();
    await _supa.from('inventory_monthly_cut_lines').insert(lines);
  }

  Future<void> _capturePhysicalStock(Map<String, dynamic> line) async {
    final currentPhysical = _toNum(line['physical_stock']) ?? 0;
    final c = TextEditingController(text: currentPhysical.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContractConfirmDialogKeyHandler(
        onCancel: () => Navigator.pop(dialogContext, false),
        onConfirm: () => Navigator.pop(dialogContext, true),
        child: AlertDialog(
          title: const Text('Capturar conteo fisico'),
          content: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
            ],
            decoration: const InputDecoration(labelText: 'Stock fisico'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final physical = double.tryParse(c.text.trim());
    if (physical == null || physical < 0) {
      _toast('Stock fisico invalido.');
      return;
    }

    final system = _toNum(line['system_stock']) ?? 0;
    final difference = physical - system;

    await _guardedSave(() async {
      await _supa
          .from('inventory_monthly_cut_lines')
          .update({'physical_stock': physical, 'difference': difference})
          .eq('id', line['id']);
      await _loadCutLines((line['cut_id'] ?? '').toString());
      _toast('Conteo fisico actualizado.');
    });
  }

  Future<void> _applyCutAdjustmentsAndClose() async {
    if (_selectedCutId == null) {
      _toast('Selecciona un corte.');
      return;
    }
    final selectedCut = _cuts.firstWhere(
      (c) => (c['id'] ?? '').toString() == _selectedCutId,
      orElse: () => <String, dynamic>{},
    );
    if ((selectedCut['status'] ?? '').toString() == 'cerrado') {
      _toast('Ese corte ya esta cerrado.');
      return;
    }

    final withDiff = _cutLines.where((e) {
      final diff = _toNum(e['difference']) ?? 0;
      return diff != 0;
    }).toList();

    await _guardedSave(() async {
      final userId = _supa.auth.currentUser?.id;
      for (final line in withDiff) {
        final diff = _toNum(line['difference']) ?? 0;
        await _supa.from('inventory_movements').insert({
          'item_id': line['item_id'],
          'movement_type': 'ajuste',
          'quantity': diff,
          'responsible_name': 'CORTE MENSUAL',
          'area': 'ALMACEN',
          'reason': 'Ajuste por corte mensual',
          'reference': _cutPeriodLabel(selectedCut),
          'created_by': userId,
        });
        await _supa
            .from('inventory_monthly_cut_lines')
            .update({'adjustment_applied': true})
            .eq('id', line['id']);
      }

      await _supa
          .from('inventory_monthly_cuts')
          .update({
            'status': 'cerrado',
            'closed_at': DateTime.now().toIso8601String(),
            'closed_by': userId,
          })
          .eq('id', _selectedCutId!);

      await _loadAll(showLoader: false);
      _toast('Corte cerrado y ajustes aplicados.');
    });
  }

  Future<void> _guardedSave(Future<void> Function() fn) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await fn();
    } catch (e) {
      _toast('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await signOutAndRouteToLogin(context);
  }

  Future<void> _goToDashboard() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(page: const DashboardPage(instantOpen: true)),
    );
  }

  Future<void> _goToGeneralDashboard() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!AuthAccess.canAccessGeneralDashboard(profile)) return;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
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

  Future<void> _showWarehouseUsageGuide() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Instructivo de uso - Almacén'),
        content: const SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '1) Para que sirve este modulo',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Almacén controla articulos fisicos de almacen general: su alta, sus entradas y salidas, y el corte mensual contra existencia real.',
                ),
                SizedBox(height: 10),
                Text(
                  '2) Cuando se usa cada pestaña',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Inventario: para dar de alta articulos, revisar stock actual, minimo, ubicacion y estado.',
                ),
                Text(
                  'Movimientos: para registrar cada entrada, salida o ajuste que afecta existencias.',
                ),
                Text(
                  'Corte mensual: para comparar stock del sistema contra conteo fisico y cerrar diferencias del mes.',
                ),
                SizedBox(height: 10),
                Text(
                  '3) Flujo operativo recomendado',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text('1. Da de alta el articulo una sola vez en Inventario.'),
                Text(
                  '2. Cada vez que entra o sale material, registralo en Movimientos con responsable y motivo.',
                ),
                Text(
                  '3. Revisa bajo stock para anticipar reposicion o riesgo operativo.',
                ),
                Text(
                  '4. Al cierre del mes, abre o reutiliza el corte del periodo y captura el conteo fisico real.',
                ),
                Text(
                  '5. Cuando el conteo este validado, aplica ajustes y cierra el corte.',
                ),
                SizedBox(height: 10),
                Text(
                  '4) Que pasa al registrar un movimiento',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Cada entrada aumenta stock. Cada salida lo disminuye. El sistema no deja registrar una salida mayor al stock disponible.',
                ),
                Text(
                  'El historial de Movimientos es la trazabilidad del almacen; no conviene corregir stock saltandose ese registro.',
                ),
                SizedBox(height: 10),
                Text(
                  '5) Como funciona el corte mensual',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Al abrir un corte, el sistema toma el stock actual de cada articulo y genera una linea de conteo.',
                ),
                Text(
                  'Despues capturas el stock fisico real. La diferencia contra el sistema se guarda por articulo.',
                ),
                Text(
                  'Al aplicar ajustes, el sistema registra movimientos tipo ajuste por cada diferencia y marca el corte como cerrado.',
                ),
                Text(
                  'Si el periodo ya existe, no crea otro; reutiliza el mismo corte para evitar duplicados.',
                ),
                SizedBox(height: 10),
                Text(
                  '6) Reglas importantes',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'No cierres un corte si el conteo fisico aun no esta validado, porque el cierre genera movimientos de ajuste reales.',
                ),
                Text(
                  'Si corriges un movimiento ya registrado, cambias el stock actual y tambien el siguiente corte.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return ServicesShell(
      headerTitle: 'Almacen',
      activeOverlayModule: ServicesOverlayNavModule.almacen,
      onLogout: _logout,
      onGoToGeneralDashboard: _goToGeneralDashboard,
      onGoToOperacion: _goToDashboard,
      onGoToEntriesAndOutputs: _goToEntriesAndOutputs,
      onGoToProduction: _goToProduction,
      onGoToInventory: _goToInventory,
      onGoToServices: _goToServices,
      onGoToWeighings: _goToWeighings,
      onGoToMaintenance: _goToMaintenance,
      onGoToWarehouse: () async {},
      onHeaderGuide: _showWarehouseUsageGuide,
      headerGuideLabel: 'Instructivo',
      topContent: _buildTopContent(),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: OperationalFolderTabs(
                    controller: _tabs,
                    maxWidth: 700,
                    showBottomRail: false,
                    showSelectedRail: false,
                    items: const [
                      OperationalFolderTabItem(
                        label: 'Resumen',
                        icon: Icons.dashboard_outlined,
                      ),
                      OperationalFolderTabItem(
                        label: 'Inventario',
                        icon: Icons.inventory_2_outlined,
                      ),
                      OperationalFolderTabItem(
                        label: 'Movimientos',
                        icon: Icons.swap_horiz_rounded,
                      ),
                      OperationalFolderTabItem(
                        label: 'Corte mensual',
                        icon: Icons.calendar_month_rounded,
                      ),
                      OperationalFolderTabItem(
                        label: 'Reportes',
                        icon: Icons.insert_chart_outlined_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _buildSummaryTab(),
                      _buildInventoryTab(),
                      _buildMovementsTab(),
                      _buildMonthlyCutTab(),
                      _buildReportsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTopContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OperationalGlassToolbarPanel(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  style: _warehouseActionFilledButtonStyle(),
                  onPressed: _saving ? null : _createItem,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Nuevo articulo'),
                ),
                FilledButton.icon(
                  style: _warehouseActionFilledButtonStyle(),
                  onPressed: _saving ? null : _registerMovement,
                  icon: const Icon(Icons.playlist_add_check_circle_outlined),
                  label: const Text('Registrar movimiento'),
                ),
                OutlinedButton.icon(
                  style: _warehouseActionOutlinedButtonStyle(),
                  onPressed: _saving ? null : _openMonthlyCut,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('Abrir corte mensual'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                OperationalMetricCard(
                  icon: Icons.inventory,
                  label: 'ARTICULOS ACTIVOS',
                  value: _activeItemsCount.toString(),
                  subtitle: '${_items.length} totales',
                ),
                OperationalMetricCard(
                  icon: Icons.warning_amber_rounded,
                  label: 'BAJO STOCK',
                  value: _lowStockItems.length.toString(),
                  subtitle: 'Requieren reabasto',
                ),
                OperationalMetricCard(
                  icon: Icons.swap_horiz_rounded,
                  label: 'MOVIMIENTOS DEL MES',
                  value: _monthMovementsCount.toString(),
                  subtitle: 'Mes en curso',
                ),
                OperationalMetricCard(
                  icon: Icons.tune_rounded,
                  label: 'AJUSTES DEL MES',
                  value: _monthAdjustmentsCount.toString(),
                  subtitle: 'Tipo ajuste',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    final lowStock = _lowStockItems.take(12).toList();
    final recentMovements = _movements.take(14).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: _glassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bajo stock',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: lowStock.isEmpty
                        ? const Center(child: Text('Sin articulos criticos.'))
                        : ListView.separated(
                            itemCount: lowStock.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 8),
                            itemBuilder: (context, index) {
                              final row = lowStock[index];
                              final stock = _toNum(row['current_stock']) ?? 0;
                              final minimum = _toNum(row['minimum_stock']) ?? 0;
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${row['name'] ?? '-'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${row['location'] ?? '-'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  '${_fmtQty(stock)} / ${_fmtQty(minimum)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFC62828),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _glassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Movimientos recientes',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: recentMovements.isEmpty
                        ? const Center(child: Text('Sin movimientos.'))
                        : ListView.separated(
                            itemCount: recentMovements.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 8),
                            itemBuilder: (context, index) {
                              final row = recentMovements[index];
                              final item = Map<String, dynamic>.from(
                                (row['inventory_items'] as Map?) ?? const {},
                              );
                              final dt = _dateFromAny(row['created_at']);
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${_labelMovementType((row['movement_type'] ?? '').toString())} - ${item['name'] ?? '-'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${row['responsible_name'] ?? '-'} | ${row['area'] ?? '-'}',
                                ),
                                trailing: Text(
                                  dt == null
                                      ? '-'
                                      : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTab() {
    final rows = _filteredItems;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: _glassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: const InputDecoration(
                      labelText: 'Buscar por codigo/nombre/descripcion',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _categoryFilter,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Categoria: Todas'),
                      ),
                      ..._kWarehouseCategories.map(
                        (e) => DropdownMenuItem<String?>(
                          value: e,
                          child: Text(_labelCategory(e)),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _categoryFilter = v),
                    decoration: const InputDecoration(labelText: 'Categoria'),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _locationFilter,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Ubicacion: Todas'),
                      ),
                      ..._locationOptions.map(
                        (e) =>
                            DropdownMenuItem<String?>(value: e, child: Text(e)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _locationFilter = v),
                    decoration: const InputDecoration(labelText: 'Ubicacion'),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _stockStateFilter,
                    items: const [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Estado: Todos'),
                      ),
                      DropdownMenuItem<String?>(value: 'ok', child: Text('OK')),
                      DropdownMenuItem<String?>(
                        value: 'bajo_stock',
                        child: Text('Bajo stock'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'sin_existencia',
                        child: Text('Sin existencias'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _stockStateFilter = v),
                    decoration: const InputDecoration(labelText: 'Estado'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('Sin articulos para mostrar.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 1260,
                        child: ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            final state = _stockState(row);
                            final rowId = (row['id'] ?? '').toString();
                            return Listener(
                              onPointerDown: (event) {
                                if (event.buttons == kSecondaryMouseButton) {
                                  unawaited(
                                    _openInventoryRowContextMenu(
                                      event.position,
                                      row: row,
                                    ),
                                  );
                                }
                              },
                              child: _buildSelectableRowCard(
                                rowId: rowId,
                                selectedRowId: _selectedInventoryRowId,
                                hoveredRowId: _hoveredInventoryRowId,
                                onRowSelected: (id) => setState(
                                  () => _selectedInventoryRowId = id,
                                ),
                                onHoveredChanged: (id) =>
                                    setState(() => _hoveredInventoryRowId = id),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: ContractGridScaledRow(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 120,
                                          child: Text(
                                            '${row['code'] ?? '-'}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 240,
                                          child: Text(
                                            '${row['name'] ?? '-'}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 120,
                                          child: Text(
                                            _labelCategory(
                                              (row['category'] ?? '')
                                                  .toString(),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 90,
                                          child: Text('${row['unit'] ?? '-'}'),
                                        ),
                                        SizedBox(
                                          width: 90,
                                          child: Text(
                                            _fmtQty(
                                              _toNum(row['current_stock']) ?? 0,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 90,
                                          child: Text(
                                            _fmtQty(
                                              _toNum(row['minimum_stock']) ?? 0,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 160,
                                          child: Text(
                                            '${row['location'] ?? '-'}',
                                          ),
                                        ),
                                        SizedBox(
                                          width: 130,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _stockStateColor(
                                                  state,
                                                ).withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: _stockStateColor(
                                                    state,
                                                  ).withValues(alpha: 0.45),
                                                ),
                                              ),
                                              child: Text(
                                                _stockStateLabel(state),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: _stockStateColor(
                                                    state,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 150,
                                          child: Wrap(
                                            spacing: 4,
                                            children: [
                                              TextButton(
                                                onPressed: _saving
                                                    ? null
                                                    : () =>
                                                          _registerMovementForItem(
                                                            rowId,
                                                            'entrada',
                                                          ),
                                                child: const Text('Entrada'),
                                              ),
                                              TextButton(
                                                onPressed: _saving
                                                    ? null
                                                    : () =>
                                                          _registerMovementForItem(
                                                            rowId,
                                                            'salida',
                                                          ),
                                                child: const Text('Salida'),
                                              ),
                                            ],
                                          ),
                                        ),
                                        AnchoredActionSlot(
                                          width: _kWarehouseInventoryActionsW,
                                          trailingWidth:
                                              _kWarehouseInventoryActionsW,
                                          leading: const SizedBox.shrink(),
                                          trailing: _WarehouseRowActionsButton(
                                            onTapDown: (globalPosition) {
                                              unawaited(
                                                _openInventoryRowContextMenu(
                                                  globalPosition,
                                                  row: row,
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
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerMovementForItem(String itemId, String type) async {
    final selected = _items.firstWhere(
      (item) => (item['id'] ?? '').toString() == itemId,
      orElse: () => <String, dynamic>{},
    );
    if (selected.isEmpty) return;

    final qtyC = TextEditingController();
    final areaC = TextEditingController();
    final responsibleC = TextEditingController();
    final reasonC = TextEditingController();
    final refC = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${type == 'entrada' ? 'Entrada' : 'Salida'} rapida'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${selected['code'] ?? '-'} - ${selected['name'] ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyC,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
                ],
                decoration: const InputDecoration(labelText: 'Cantidad *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: areaC,
                decoration: const InputDecoration(labelText: 'Area'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: responsibleC,
                decoration: const InputDecoration(labelText: 'Responsable *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonC,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Motivo *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: refC,
                decoration: const InputDecoration(labelText: 'Referencia'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final quantity = double.tryParse(qtyC.text.trim());
    final currentStock = _toNum(selected['current_stock']) ?? 0;
    if (quantity == null || quantity <= 0) {
      _toast('Cantidad invalida.');
      return;
    }
    if (type == 'salida' && quantity > currentStock) {
      _toast('No se permite salida mayor al stock actual.');
      return;
    }

    final responsible = responsibleC.text.trim();
    final reason = reasonC.text.trim();
    if (responsible.isEmpty || reason.isEmpty) {
      _toast('Responsable y motivo son obligatorios.');
      return;
    }

    await _guardedSave(() async {
      await _supa.from('inventory_movements').insert({
        'item_id': itemId,
        'movement_type': type,
        'quantity': quantity,
        'area': areaC.text.trim().isEmpty ? null : areaC.text.trim(),
        'responsible_name': responsible,
        'reason': reason,
        'reference': refC.text.trim().isEmpty ? null : refC.text.trim(),
        'created_by': _supa.auth.currentUser?.id,
      });
      await _loadAll(showLoader: false);
      _toast('Movimiento registrado.');
    });
  }

  bool _isEditableTextFocused() {
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  Set<String> _currentMovementSelection() {
    if (_selectedMovementIds.isNotEmpty) return {..._selectedMovementIds};
    if (_selectedMovementRowId == null) return <String>{};
    return <String>{_selectedMovementRowId!};
  }

  void _selectMovementRow(
    String rowId, {
    bool additive = false,
    bool range = false,
  }) {
    if (rowId.isEmpty) return;
    final idsInOrder = _movements
        .map((r) => (r['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
    final rowIndex = idsInOrder.indexOf(rowId);
    if (rowIndex < 0) return;

    setState(() {
      final current = _currentMovementSelection();
      if (range && _selectedMovementRowId != null) {
        final anchor = idsInOrder.indexOf(_selectedMovementRowId!);
        if (anchor >= 0) {
          final start = anchor < rowIndex ? anchor : rowIndex;
          final end = anchor < rowIndex ? rowIndex : anchor;
          final span = idsInOrder.sublist(start, end + 1).toSet();
          _selectedMovementIds
            ..clear()
            ..addAll(current)
            ..addAll(span);
          _selectedMovementRowId = rowId;
          return;
        }
      }

      if (additive) {
        if (_selectedMovementIds.isEmpty && _selectedMovementRowId != null) {
          _selectedMovementIds.add(_selectedMovementRowId!);
        }
        if (_selectedMovementIds.contains(rowId)) {
          _selectedMovementIds.remove(rowId);
          if (_selectedMovementRowId == rowId) {
            _selectedMovementRowId = _selectedMovementIds.isEmpty
                ? null
                : _selectedMovementIds.first;
          }
        } else {
          _selectedMovementIds.add(rowId);
          _selectedMovementRowId = rowId;
        }
        return;
      }

      _selectedMovementIds
        ..clear()
        ..add(rowId);
      _selectedMovementRowId = rowId;
    });
  }

  void _clearMovementSelection() {
    setState(() {
      _selectedMovementIds.clear();
      _selectedMovementRowId = null;
      _movementDragSelecting = false;
      _movementDragAnchorRowId = null;
      _movementDragBaseSelection = <String>{};
      _suppressNextMovementTapSelection = false;
    });
  }

  void _beginMovementDragSelection(String rowId, {required bool additive}) {
    if (rowId.isEmpty) return;
    setState(() {
      final base = additive ? _currentMovementSelection() : <String>{};
      _movementDragSelecting = true;
      _movementDragAnchorRowId = rowId;
      _movementDragBaseSelection = base;
      _suppressNextMovementTapSelection = true;
      _selectedMovementIds
        ..clear()
        ..addAll(base)
        ..add(rowId);
      _selectedMovementRowId = rowId;
    });
  }

  void _extendMovementDragSelection(String rowId) {
    if (!_movementDragSelecting) return;
    final anchorId = _movementDragAnchorRowId;
    if (anchorId == null || rowId.isEmpty) return;
    final idsInOrder = _movements
        .map((r) => (r['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
    final anchorIndex = idsInOrder.indexOf(anchorId);
    final rowIndex = idsInOrder.indexOf(rowId);
    if (anchorIndex < 0 || rowIndex < 0) return;
    final start = anchorIndex < rowIndex ? anchorIndex : rowIndex;
    final end = anchorIndex < rowIndex ? rowIndex : anchorIndex;
    final span = idsInOrder.sublist(start, end + 1);
    setState(() {
      _selectedMovementIds
        ..clear()
        ..addAll(_movementDragBaseSelection)
        ..addAll(span);
      _selectedMovementRowId = rowId;
    });
  }

  void _endMovementDragSelection() {
    if (!_movementDragSelecting && !_suppressNextMovementTapSelection) return;
    setState(() {
      _movementDragSelecting = false;
      _movementDragAnchorRowId = null;
      _movementDragBaseSelection = <String>{};
      _suppressNextMovementTapSelection = false;
    });
  }

  void _onMovementRowHovered(String? rowId) {
    setState(() => _hoveredMovementRowId = rowId);
    if (rowId != null) {
      _extendMovementDragSelection(rowId);
    }
  }

  Future<void> _moveMovementSelectionByKeyboard({
    required int delta,
    required bool extend,
  }) async {
    final idsInOrder = _movements
        .map((r) => (r['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
    if (idsInOrder.isEmpty) return;
    var currentIndex = _selectedMovementRowId == null
        ? -1
        : idsInOrder.indexOf(_selectedMovementRowId!);
    if (currentIndex < 0) currentIndex = 0;
    final next = (currentIndex + delta).clamp(0, idsInOrder.length - 1);
    final nextId = idsInOrder[next];
    _selectMovementRow(nextId, additive: extend, range: extend);
  }

  void _setPrimaryMovementRowPreservingSelection(String rowId) {
    if (rowId.isEmpty) return;
    final current = _currentMovementSelection();
    if (current.contains(rowId)) {
      setState(() => _selectedMovementRowId = rowId);
      return;
    }
    _selectMovementRow(rowId);
  }

  Future<void> _openMovementRowContextMenu(
    Offset globalPos, {
    required String rowId,
  }) async {
    _setPrimaryMovementRowPreservingSelection(rowId);
    final selected = _currentMovementSelection();
    final choice = await _showMovementRowsContextMenu(
      globalPos,
      selectedCount: selected.length,
    );
    if (!mounted || choice == null) return;
    if (choice == 'edit') {
      await _editSelectedMovements();
    } else if (choice == 'delete') {
      await _deleteSelectedMovements();
    }
  }

  Future<String?> _showMovementRowsContextMenu(
    Offset globalPosition, {
    required int selectedCount,
  }) {
    final actions = <MapEntry<String, String>>[
      MapEntry(
        'edit',
        selectedCount > 1
            ? 'EDITAR SELECCION ($selectedCount)'
            : 'EDITAR MOVIMIENTO',
      ),
      MapEntry(
        'delete',
        selectedCount > 1
            ? 'ELIMINAR SELECCION ($selectedCount)'
            : 'ELIMINAR MOVIMIENTO',
      ),
    ];
    const menuTextStyle = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
      color: Color(0xFF1C3E5D),
    );
    final mediaSize = MediaQuery.of(context).size;
    return showMenu<String>(
      context: context,
      color: const Color(0xE6EAF2F9),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        mediaSize.width - globalPosition.dx,
        mediaSize.height - globalPosition.dy,
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

  Future<String?> _showInventoryRowContextMenu(
    Offset globalPosition, {
    required String itemName,
  }) {
    const menuTextStyle = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
      color: Color(0xFF1C3E5D),
    );
    final mediaSize = MediaQuery.of(context).size;
    return showMenu<String>(
      context: context,
      color: const Color(0xE6EAF2F9),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        mediaSize.width - globalPosition.dx,
        mediaSize.height - globalPosition.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'entrada',
          child: Text('ENTRADA · $itemName', style: menuTextStyle),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'salida',
          child: Text('SALIDA · $itemName', style: menuTextStyle),
        ),
      ],
    );
  }

  Future<void> _openInventoryRowContextMenu(
    Offset globalPosition, {
    required Map<String, dynamic> row,
  }) async {
    final rowId = (row['id'] ?? '').toString();
    if (rowId.isEmpty) return;
    setState(() => _selectedInventoryRowId = rowId);
    final choice = await _showInventoryRowContextMenu(
      globalPosition,
      itemName: (row['name'] ?? '-').toString(),
    );
    if (!mounted || choice == null) return;
    if (choice == 'entrada' || choice == 'salida') {
      await _registerMovementForItem(rowId, choice);
    }
  }

  Future<String?> _showCutLineContextMenu(
    Offset globalPosition, {
    required bool adjustmentApplied,
  }) {
    const menuTextStyle = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
      color: Color(0xFF1C3E5D),
    );
    final mediaSize = MediaQuery.of(context).size;
    return showMenu<String>(
      context: context,
      color: const Color(0xE6EAF2F9),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        mediaSize.width - globalPosition.dx,
        mediaSize.height - globalPosition.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'capture',
          child: Text(
            adjustmentApplied
                ? 'ACTUALIZAR CONTEO FISICO'
                : 'CAPTURAR CONTEO FISICO',
            style: menuTextStyle,
          ),
        ),
      ],
    );
  }

  Future<void> _openCutLineContextMenu(
    Offset globalPosition, {
    required Map<String, dynamic> row,
  }) async {
    final rowId = (row['id'] ?? '').toString();
    if (rowId.isEmpty) return;
    setState(() => _selectedCutLineRowId = rowId);
    final choice = await _showCutLineContextMenu(
      globalPosition,
      adjustmentApplied: (row['adjustment_applied'] as bool?) == true,
    );
    if (!mounted || choice == null) return;
    if (choice == 'capture') {
      await _capturePhysicalStock(row);
    }
  }

  Future<void> _editSelectedMovements() async {
    final selectedIds = _currentMovementSelection().toList();
    if (selectedIds.isEmpty) {
      _toast('Selecciona al menos un movimiento.');
      return;
    }
    final selectedRows = _movements
        .where((r) => selectedIds.contains((r['id'] ?? '').toString()))
        .toList();
    if (selectedRows.isEmpty) return;

    final first = selectedRows.first;
    final areaC = TextEditingController(
      text: selectedRows.length == 1 ? (first['area'] ?? '').toString() : '',
    );
    final responsibleC = TextEditingController(
      text: selectedRows.length == 1
          ? (first['responsible_name'] ?? '').toString()
          : '',
    );
    final reasonC = TextEditingController(
      text: selectedRows.length == 1 ? (first['reason'] ?? '').toString() : '',
    );
    final referenceC = TextEditingController(
      text: selectedRows.length == 1
          ? (first['reference'] ?? '').toString()
          : '',
    );
    bool applyArea = selectedRows.length == 1;
    bool applyResponsible = selectedRows.length == 1;
    bool applyReason = selectedRows.length == 1;
    bool applyReference = selectedRows.length == 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(
            selectedRows.length > 1
                ? 'Editar movimientos (${selectedRows.length})'
                : 'Editar movimiento',
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedRows.length > 1) ...[
                  CheckboxListTile(
                    value: applyArea,
                    onChanged: (v) =>
                        setLocalState(() => applyArea = v == true),
                    title: const Text('Actualizar area'),
                    dense: true,
                  ),
                ],
                TextField(
                  controller: areaC,
                  decoration: const InputDecoration(labelText: 'Area'),
                ),
                const SizedBox(height: 8),
                if (selectedRows.length > 1) ...[
                  CheckboxListTile(
                    value: applyResponsible,
                    onChanged: (v) =>
                        setLocalState(() => applyResponsible = v == true),
                    title: const Text('Actualizar responsable'),
                    dense: true,
                  ),
                ],
                TextField(
                  controller: responsibleC,
                  decoration: const InputDecoration(labelText: 'Responsable'),
                ),
                const SizedBox(height: 8),
                if (selectedRows.length > 1) ...[
                  CheckboxListTile(
                    value: applyReason,
                    onChanged: (v) =>
                        setLocalState(() => applyReason = v == true),
                    title: const Text('Actualizar motivo'),
                    dense: true,
                  ),
                ],
                TextField(
                  controller: reasonC,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Motivo'),
                ),
                const SizedBox(height: 8),
                if (selectedRows.length > 1) ...[
                  CheckboxListTile(
                    value: applyReference,
                    onChanged: (v) =>
                        setLocalState(() => applyReference = v == true),
                    title: const Text('Actualizar referencia'),
                    dense: true,
                  ),
                ],
                TextField(
                  controller: referenceC,
                  decoration: const InputDecoration(labelText: 'Referencia'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final updates = <String, dynamic>{};
    if (selectedRows.length == 1 || applyArea) {
      updates['area'] = areaC.text.trim().isEmpty ? null : areaC.text.trim();
    }
    if (selectedRows.length == 1 || applyResponsible) {
      final value = responsibleC.text.trim();
      if (value.isNotEmpty) updates['responsible_name'] = value;
    }
    if (selectedRows.length == 1 || applyReason) {
      final value = reasonC.text.trim();
      if (value.isNotEmpty) updates['reason'] = value;
    }
    if (selectedRows.length == 1 || applyReference) {
      updates['reference'] = referenceC.text.trim().isEmpty
          ? null
          : referenceC.text.trim();
    }

    if (updates.isEmpty) {
      _toast('No hay cambios para aplicar.');
      return;
    }

    await _guardedSave(() async {
      for (final id in selectedIds) {
        await _supa.from('inventory_movements').update(updates).eq('id', id);
      }
      await _loadAll(showLoader: false);
      _toast(
        selectedIds.length > 1
            ? 'Movimientos actualizados (${selectedIds.length}).'
            : 'Movimiento actualizado.',
      );
    });
  }

  Future<void> _deleteSelectedMovements() async {
    final selectedIds = _currentMovementSelection().toList();
    if (selectedIds.isEmpty) {
      _toast('Selecciona al menos un movimiento.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContractConfirmDialogKeyHandler(
        onCancel: () => Navigator.pop(dialogContext, false),
        onConfirm: () => Navigator.pop(dialogContext, true),
        child: AlertDialog(
          title: const Text('Eliminar movimientos'),
          content: Text(
            selectedIds.length > 1
                ? 'Se eliminaran ${selectedIds.length} movimientos seleccionados. ¿Continuar?'
                : 'Se eliminara el movimiento seleccionado. ¿Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    await _guardedSave(() async {
      await _supa
          .from('inventory_movements')
          .delete()
          .inFilter('id', selectedIds);
      await _loadAll(showLoader: false);
      _clearMovementSelection();
      _toast(
        selectedIds.length > 1
            ? 'Movimientos eliminados (${selectedIds.length}).'
            : 'Movimiento eliminado.',
      );
    });
  }

  KeyEventResult _onMovementsKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isEditableTextFocused()) return KeyEventResult.ignored;

    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final extend = isCtrl || isMeta;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      unawaited(
        _moveMovementSelectionByKeyboard(delta: 1, extend: extend || isShift),
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      unawaited(
        _moveMovementSelectionByKeyboard(delta: -1, extend: extend || isShift),
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _clearMovementSelection();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      unawaited(_deleteSelectedMovements());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      unawaited(_editSelectedMovements());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildMovementsTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: _glassPanel(
        child: Focus(
          autofocus: true,
          focusNode: _movementsFocusNode,
          onKeyEvent: (_, event) => _onMovementsKeyEvent(event),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '${_currentMovementSelection().length} seleccionados',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: _warehouseActionOutlinedButtonStyle(),
                    onPressed: _currentMovementSelection().isEmpty
                        ? null
                        : _editSelectedMovements,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    style: _warehouseActionFilledButtonStyle(),
                    onPressed: _currentMovementSelection().isEmpty
                        ? null
                        : _deleteSelectedMovements,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Listener(
                  onPointerUp: (_) => _endMovementDragSelection(),
                  onPointerCancel: (_) => _endMovementDragSelection(),
                  child: _movements.isEmpty
                      ? const Center(child: Text('Sin movimientos.'))
                      : ListView.builder(
                          itemCount: _movements.length,
                          itemBuilder: (context, index) {
                            final row = _movements[index];
                            final item = Map<String, dynamic>.from(
                              (row['inventory_items'] as Map?) ?? const {},
                            );
                            final dt = _dateFromAny(row['created_at']);
                            final rowId = (row['id'] ?? '').toString();
                            return Listener(
                              onPointerDown: (event) {
                                if (event.buttons == kSecondaryMouseButton) {
                                  unawaited(
                                    _openMovementRowContextMenu(
                                      event.position,
                                      rowId: rowId,
                                    ),
                                  );
                                  return;
                                }
                                if (event.buttons == kPrimaryMouseButton) {
                                  final additive =
                                      HardwareKeyboard
                                          .instance
                                          .isControlPressed ||
                                      HardwareKeyboard.instance.isMetaPressed;
                                  _beginMovementDragSelection(
                                    rowId,
                                    additive: additive,
                                  );
                                  _movementsFocusNode.requestFocus();
                                }
                              },
                              child: _buildSelectableRowCard(
                                rowId: rowId,
                                selectedRowId: _selectedMovementRowId,
                                selectedRowIds: _selectedMovementIds,
                                hoveredRowId: _hoveredMovementRowId,
                                onRowSelected: (id) {
                                  if (_suppressNextMovementTapSelection) {
                                    _suppressNextMovementTapSelection = false;
                                    return;
                                  }
                                  final additive =
                                      HardwareKeyboard
                                          .instance
                                          .isControlPressed ||
                                      HardwareKeyboard.instance.isMetaPressed;
                                  final range =
                                      HardwareKeyboard.instance.isShiftPressed;
                                  _selectMovementRow(
                                    id,
                                    additive: additive,
                                    range: range,
                                  );
                                  _movementsFocusNode.requestFocus();
                                },
                                onHoveredChanged: _onMovementRowHovered,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      _movementCell(
                                        dt == null
                                            ? '-'
                                            : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}',
                                        flex: 12,
                                        weight: FontWeight.w700,
                                      ),
                                      _movementCell(
                                        _labelMovementType(
                                          '${row['movement_type'] ?? '-'}',
                                        ),
                                        flex: 12,
                                      ),
                                      _movementCell(
                                        '${item['name'] ?? '-'}',
                                        flex: 24,
                                      ),
                                      _movementCell(
                                        _fmtQty(_toNum(row['quantity']) ?? 0),
                                        flex: 10,
                                        align: TextAlign.right,
                                      ),
                                      _movementCell(
                                        '${row['responsible_name'] ?? '-'}',
                                        flex: 17,
                                      ),
                                      _movementCell(
                                        '${row['area'] ?? '-'}',
                                        flex: 14,
                                      ),
                                      _movementCell(
                                        '${row['reason'] ?? '-'}',
                                        flex: 20,
                                      ),
                                      _movementCell(
                                        '${row['reference'] ?? '-'}',
                                        flex: 14,
                                      ),
                                      SizedBox(
                                        width: 42,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: _WarehouseRowActionsButton(
                                            onTapDown: (globalPosition) {
                                              unawaited(
                                                _openMovementRowContextMenu(
                                                  globalPosition,
                                                  rowId: rowId,
                                                ),
                                              );
                                            },
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _movementCell(
    String text, {
    required int flex,
    FontWeight weight = FontWeight.w500,
    TextAlign align = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TextStyle(fontWeight: weight),
        ),
      ),
    );
  }

  Widget _buildMonthlyCutTab() {
    final selectedCut = _cuts.firstWhere(
      (c) => (c['id'] ?? '').toString() == _selectedCutId,
      orElse: () => <String, dynamic>{},
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: _glassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 360,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedCutId,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Selecciona un corte'),
                      ),
                      ..._cuts.map(
                        (cut) => DropdownMenuItem<String?>(
                          value: (cut['id'] ?? '').toString(),
                          child: Text(_cutPeriodLabel(cut)),
                        ),
                      ),
                    ],
                    onChanged: (v) async {
                      setState(() => _selectedCutId = v);
                      if (v != null) {
                        await _loadCutLines(v);
                      } else {
                        setState(() => _cutLines = <Map<String, dynamic>>[]);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Corte mensual',
                    ),
                  ),
                ),
                if (selectedCut.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withValues(alpha: 0.62),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    child: Text(
                      'Estado: ${_labelCutStatus((selectedCut['status'] ?? '').toString())}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                if (_selectedCutId != null)
                  FilledButton.icon(
                    onPressed: _saving ? null : _applyCutAdjustmentsAndClose,
                    icon: const Icon(Icons.task_alt_rounded),
                    label: const Text('Aplicar ajustes y cerrar'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _cutLines.isEmpty
                  ? const Center(child: Text('Sin lineas de corte.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 1120,
                        child: ListView.builder(
                          itemCount: _cutLines.length,
                          itemBuilder: (context, index) {
                            final row = _cutLines[index];
                            final item = Map<String, dynamic>.from(
                              (row['inventory_items'] as Map?) ?? const {},
                            );
                            final diff = _toNum(row['difference']) ?? 0;
                            final rowId = (row['id'] ?? '').toString();
                            return Listener(
                              onPointerDown: (event) {
                                if (event.buttons == kSecondaryMouseButton) {
                                  unawaited(
                                    _openCutLineContextMenu(
                                      event.position,
                                      row: row,
                                    ),
                                  );
                                }
                              },
                              child: _buildSelectableRowCard(
                                rowId: rowId,
                                selectedRowId: _selectedCutLineRowId,
                                hoveredRowId: _hoveredCutLineRowId,
                                onRowSelected: (id) =>
                                    setState(() => _selectedCutLineRowId = id),
                                onHoveredChanged: (id) =>
                                    setState(() => _hoveredCutLineRowId = id),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: ContractGridScaledRow(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 290,
                                          child: Text(
                                            '${item['code'] ?? '-'} - ${item['name'] ?? '-'}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 130,
                                          child: Text(
                                            _fmtQty(
                                              _toNum(row['system_stock']) ?? 0,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 130,
                                          child: Text(
                                            _fmtQty(
                                              _toNum(row['physical_stock']) ??
                                                  0,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 130,
                                          child: Text(
                                            _fmtQty(diff),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: diff == 0
                                                  ? const Color(0xFF2E7D32)
                                                  : const Color(0xFFC62828),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 170,
                                          child: Text(
                                            (row['adjustment_applied']
                                                        as bool?) ==
                                                    true
                                                ? 'Aplicado'
                                                : 'Pendiente',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 170,
                                          child: TextButton.icon(
                                            onPressed: _saving
                                                ? null
                                                : () => _capturePhysicalStock(
                                                    row,
                                                  ),
                                            icon: const Icon(
                                              Icons.edit_rounded,
                                            ),
                                            label: const Text(
                                              'Capturar fisico',
                                            ),
                                          ),
                                        ),
                                        AnchoredActionSlot(
                                          width: _kWarehouseCutLinesActionsW,
                                          trailingWidth:
                                              _kWarehouseCutLinesActionsW,
                                          leading: const SizedBox.shrink(),
                                          trailing: _WarehouseRowActionsButton(
                                            onTapDown: (globalPosition) {
                                              unawaited(
                                                _openCutLineContextMenu(
                                                  globalPosition,
                                                  row: row,
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
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    final now = DateTime.now();
    final monthRows = _movements.where((row) {
      final dt = _dateFromAny(row['created_at']);
      return dt != null && dt.year == now.year && dt.month == now.month;
    }).toList();

    final Map<String, double> qtyByArea = <String, double>{};
    final Map<String, double> qtyByType = <String, double>{};

    for (final row in monthRows) {
      final area = (row['area'] ?? 'Sin area').toString();
      final type = (row['movement_type'] ?? '').toString();
      final qty = _toNum(row['quantity']) ?? 0;
      qtyByArea[area] = (qtyByArea[area] ?? 0) + qty;
      qtyByType[type] = (qtyByType[type] ?? 0) + qty;
    }

    final areaEntries = qtyByArea.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final typeEntries = qtyByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: _glassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consumo por area (${_monthNameEs(now.month)} ${now.year})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: areaEntries.isEmpty
                        ? const Center(child: Text('Sin datos.'))
                        : ListView.separated(
                            itemCount: areaEntries.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 8),
                            itemBuilder: (context, index) {
                              final entry = areaEntries[index];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                trailing: Text(
                                  _fmtQty(entry.value),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _glassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Movimientos por tipo (${_monthNameEs(now.month)} ${now.year})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: typeEntries.isEmpty
                        ? const Center(child: Text('Sin datos.'))
                        : ListView.separated(
                            itemCount: typeEntries.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 8),
                            itemBuilder: (context, index) {
                              final entry = typeEntries[index];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  _labelMovementType(entry.key),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                trailing: Text(
                                  _fmtQty(entry.value),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassPanel({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.44)),
            boxShadow: [
              BoxShadow(
                blurRadius: 26,
                color: Colors.black.withValues(alpha: 0.10),
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSelectableRowCard({
    required String rowId,
    required String? selectedRowId,
    Set<String>? selectedRowIds,
    required String? hoveredRowId,
    required ValueChanged<String> onRowSelected,
    required ValueChanged<String?> onHoveredChanged,
    required Widget child,
  }) {
    final selected =
        rowId.isNotEmpty &&
        ((selectedRowIds != null && selectedRowIds.contains(rowId)) ||
            selectedRowId == rowId);
    final hovered = rowId.isNotEmpty && hoveredRowId == rowId;
    final bgColor = selected
        ? const Color(0xFF2F5EAA).withValues(alpha: 0.24)
        : hovered
        ? Colors.white.withValues(alpha: 0.84)
        : Colors.white.withValues(alpha: 0.74);
    final borderColor = selected
        ? const Color(0xFF1D4D8F).withValues(alpha: 0.64)
        : Colors.white.withValues(alpha: 0.68);

    return MouseRegion(
      onEnter: (_) {
        if (rowId.isEmpty) return;
        onHoveredChanged(rowId);
      },
      onExit: (_) {
        if (rowId.isEmpty) return;
        onHoveredChanged(null);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: rowId.isEmpty ? null : () => onRowSelected(rowId),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          scale: hovered && !selected ? 1.002 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        blurRadius: 18,
                        color: const Color(0xFF2F5EAA).withValues(alpha: 0.25),
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : hovered
                  ? [
                      BoxShadow(
                        blurRadius: 12,
                        color: Colors.black.withValues(alpha: 0.10),
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const [],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _WarehouseRowActionsButton extends StatefulWidget {
  final ValueChanged<Offset> onTapDown;

  const _WarehouseRowActionsButton({required this.onTapDown});

  @override
  State<_WarehouseRowActionsButton> createState() =>
      _WarehouseRowActionsButtonState();
}

class _WarehouseRowActionsButtonState
    extends State<_WarehouseRowActionsButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => widget.onTapDown(details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.62)
                : Colors.white.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.15 : 0.08),
                blurRadius: _hovered ? 14 : 8,
                offset: Offset(0, _hovered ? 7 : 4),
              ),
            ],
          ),
          child: const Icon(Icons.more_horiz, size: 20),
        ),
      ),
    );
  }
}

String _labelCategory(String value) {
  switch (value) {
    case 'herramienta':
      return 'Herramienta';
    case 'uniforme':
      return 'Uniforme';
    case 'material':
      return 'Material';
    case 'consumible':
      return 'Consumible';
    case 'refaccion':
      return 'Refaccion';
    default:
      return value;
  }
}

ButtonStyle _warehouseActionOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF0B2B2B),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.52)),
    backgroundColor: Colors.white.withValues(alpha: 0.18),
    textStyle: const TextStyle(fontWeight: FontWeight.w700),
  );
}

ButtonStyle _warehouseActionFilledButtonStyle() {
  return FilledButton.styleFrom(
    foregroundColor: const Color(0xFF0B2B2B),
    backgroundColor: Colors.white.withValues(alpha: 0.36),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.74)),
    textStyle: const TextStyle(fontWeight: FontWeight.w700),
  );
}

String _labelMovementType(String value) {
  switch (value) {
    case 'apertura':
      return 'Apertura';
    case 'entrada':
      return 'Entrada';
    case 'salida':
      return 'Salida';
    case 'ajuste':
      return 'Ajuste';
    case 'cierre':
      return 'Cierre';
    default:
      return value;
  }
}

String _labelCutStatus(String value) {
  switch (value) {
    case 'abierto':
      return 'Abierto';
    case 'en_revision':
      return 'En revision';
    case 'cerrado':
      return 'Cerrado';
    default:
      return value;
  }
}

String _cutPeriodLabel(Map<String, dynamic> cut) {
  final month = (cut['month'] ?? '-').toString();
  final year = (cut['year'] ?? '-').toString();
  final period = _dateFromAny(cut['period_month']);
  final status = _labelCutStatus((cut['status'] ?? '').toString());
  if (period != null) {
    final pMonth = period.month.toString();
    final pYear = period.year.toString();
    return '$pMonth/$pYear - $status';
  }
  return '$month/$year - $status';
}

String _fmtQty(num value) {
  if (value == value.roundToDouble()) {
    return formatDecimal(value, decimals: 0);
  }
  return formatDecimal(value, decimals: 2);
}

double? _toNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _dateFromAny(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  return null;
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
