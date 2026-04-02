import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_navigation.dart';
import '../shared/app_shell.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/confirm_dialog_key_handler.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/editable_hover_capsule.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import '../services/inventory_movements_grid.dart';
import 'menudeo_dashboard_page.dart';
import 'menudeo_theme.dart';

const double _kCatalogActionsW = 118;
const double _kCounterpartyContentW = 1218;
const double _kMaterialsContentW = 1308;
const double _kPricesContentW = 1218;

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
  };

  final sb = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    sb.write(map[ch] ?? ch);
  }
  return sb.toString();
}

String _normalizeName(String raw) {
  final noAccents = _stripAccents(raw).toUpperCase();
  return noAccents.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _materialCodeFromName(String raw) {
  final normalized = _normalizeName(raw);
  final underscored = normalized.replaceAll(RegExp(r'[^A-Z0-9]+'), '_');
  return underscored
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

List<Map<String, dynamic>> _rowsFrom(dynamic data) {
  return (data as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList(growable: false);
}

class MenudeoCatalogPage extends StatefulWidget {
  const MenudeoCatalogPage({super.key});

  @override
  State<MenudeoCatalogPage> createState() => _MenudeoCatalogPageState();
}

class _MenudeoCatalogPageState extends State<MenudeoCatalogPage> {
  final SupabaseClient _supa = Supabase.instance.client;

  bool _loading = true;
  final bool _showInactive = false;
  String? _error;
  String? _selectedRowKey;
  String? _selectionAnchorRowKey;
  String? _editingRowKey;
  final Set<String> _bulkSelectedRowKeys = <String>{};
  bool _multiEditMode = false;

  final TextEditingController _counterpartyDraftNameC = TextEditingController();
  final TextEditingController _counterpartyDraftGroupC = TextEditingController(
    text: 'GENERAL',
  );
  final TextEditingController _counterpartyDraftNotesC =
      TextEditingController();
  final TextEditingController _materialDraftNameC = TextEditingController();
  final TextEditingController _materialDraftNotesC = TextEditingController();
  final TextEditingController _priceDraftAmountC = TextEditingController();
  final TextEditingController _priceDraftNotesC = TextEditingController();
  final FocusNode _counterpartyDraftNameFocus = FocusNode();
  final FocusNode _gridRowsFocusNode = FocusNode(debugLabel: 'men_rows_focus');
  final FocusNode _counterpartyDraftKindFocus = FocusNode();
  final FocusNode _counterpartyDraftGroupFocus = FocusNode();
  final FocusNode _counterpartyDraftSiteFocus = FocusNode();
  final FocusNode _counterpartyDraftNotesFocus = FocusNode();
  final FocusNode _materialDraftLevelFocus = FocusNode();
  final FocusNode _materialDraftNameFocus = FocusNode();
  final FocusNode _materialDraftFamilyFocus = FocusNode();
  final FocusNode _materialDraftRelationFocus = FocusNode();
  final FocusNode _materialDraftNotesFocus = FocusNode();
  final FocusNode _priceDraftCounterpartyFocus = FocusNode();
  final FocusNode _priceDraftMaterialFocus = FocusNode();
  final FocusNode _priceDraftAmountFocus = FocusNode();
  final FocusNode _priceDraftNotesFocus = FocusNode();

  List<Map<String, dynamic>> _counterparties = [];
  List<Map<String, dynamic>> _generalMaterials = [];
  List<Map<String, dynamic>> _commercialMaterials = [];
  List<Map<String, dynamic>> _materialAliases = [];
  List<Map<String, dynamic>> _prices = [];
  List<Map<String, dynamic>> _sites = [];
  String _counterpartyDraftKind = 'supplier';
  String? _counterpartyDraftSiteId;
  String _materialDraftLevel = 'GENERAL';
  String _materialDraftFamily = 'other';
  String? _materialDraftGeneralMaterialId;
  String? _priceDraftCounterpartyId;
  String? _priceDraftGeneralMaterialId;
  String? _priceDraftCommercialMaterialId;
  bool _insertingCounterparty = false;
  bool _insertingMaterial = false;
  bool _insertingPrice = false;
  final Map<String, Set<String>> _columnValueFilters = <String, Set<String>>{};
  int _activeTabIndex = 0;
  bool _dragSelectionActive = false;
  List<String> _dragSelectionVisibleKeys = const <String>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadAll());
  }

  @override
  void dispose() {
    _counterpartyDraftNameC.dispose();
    _counterpartyDraftGroupC.dispose();
    _counterpartyDraftNotesC.dispose();
    _materialDraftNameC.dispose();
    _materialDraftNotesC.dispose();
    _priceDraftAmountC.dispose();
    _priceDraftNotesC.dispose();
    _counterpartyDraftNameFocus.dispose();
    _gridRowsFocusNode.dispose();
    _counterpartyDraftKindFocus.dispose();
    _counterpartyDraftGroupFocus.dispose();
    _counterpartyDraftSiteFocus.dispose();
    _counterpartyDraftNotesFocus.dispose();
    _materialDraftLevelFocus.dispose();
    _materialDraftNameFocus.dispose();
    _materialDraftFamilyFocus.dispose();
    _materialDraftRelationFocus.dispose();
    _materialDraftNotesFocus.dispose();
    _priceDraftCounterpartyFocus.dispose();
    _priceDraftMaterialFocus.dispose();
    _priceDraftAmountFocus.dispose();
    _priceDraftNotesFocus.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _goBack() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const MenudeoDashboardPage()));
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContractConfirmDialogKeyHandler(
        onCancel: () => Navigator.pop(dialogContext, false),
        onConfirm: () => Navigator.pop(dialogContext, true),
        child: AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Seguro que deseas cerrar tu sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await signOutAndRouteToLogin(context);
  }

  Future<void> _loadAll({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }

    try {
      final responses = await Future.wait<dynamic>([
        _supa
            .from('men_counterparties')
            .select()
            .order('is_active', ascending: false)
            .order('name'),
        _supa
            .from('material_general_catalog_v2')
            .select()
            .order('is_active', ascending: false)
            .order('name'),
        _supa
            .from('material_commercial_catalog_v2')
            .select()
            .order('is_active', ascending: false)
            .order('name'),
        _supa
            .from('men_material_aliases')
            .select()
            .order('is_active', ascending: false)
            .order('label'),
        _supa
            .from('men_counterparty_material_prices')
            .select()
            .order('is_active', ascending: false)
            .order('created_at', ascending: false),
        _supa.from('sites').select('id,name,type,is_active').order('name'),
      ]);

      if (!mounted) return;
      final counterparties = _rowsFrom(responses[0]);
      final generalMaterials = _rowsFrom(responses[1]);
      final commercialMaterials = _rowsFrom(responses[2]);
      final aliases = _rowsFrom(responses[3]);
      final rawPrices = _rowsFrom(responses[4]);
      final sites = _rowsFrom(responses[5]);
      setState(() {
        _counterparties = counterparties;
        _generalMaterials = generalMaterials;
        _commercialMaterials = commercialMaterials;
        _materialAliases = aliases;
        _prices = _buildPriceCatalogRows(
          rawPrices: rawPrices,
          counterparties: counterparties,
          generalMaterials: generalMaterials,
          commercialMaterials: commercialMaterials,
          aliases: aliases,
        );
        _sites = sites;
        _loading = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> _buildPriceCatalogRows({
    required List<Map<String, dynamic>> rawPrices,
    required List<Map<String, dynamic>> counterparties,
    required List<Map<String, dynamic>> generalMaterials,
    required List<Map<String, dynamic>> commercialMaterials,
    required List<Map<String, dynamic>> aliases,
  }) {
    final counterpartiesById = {
      for (final row in counterparties) (row['id'] ?? '').toString(): row,
    };
    final generalById = {
      for (final row in generalMaterials) (row['id'] ?? '').toString(): row,
    };
    final commercialById = {
      for (final row in commercialMaterials) (row['id'] ?? '').toString(): row,
    };
    final aliasesById = {
      for (final row in aliases) (row['id'] ?? '').toString(): row,
    };

    final rows = rawPrices
        .map((price) {
          final counterparty =
              counterpartiesById[(price['counterparty_id'] ?? '').toString()];
          final general =
              generalById[(price['general_material_id'] ?? '').toString()];
          final commercial =
              commercialById[(price['commercial_material_id'] ?? '')
                  .toString()];
          final alias =
              aliasesById[(price['material_alias_id'] ?? '').toString()];
          return <String, dynamic>{
            'counterparty_id': price['counterparty_id'],
            'site_id': counterparty?['site_id'],
            'counterparty_name': counterparty?['name'] ?? '',
            'kind': counterparty?['kind'] ?? '',
            'group_code': counterparty?['group_code'] ?? '',
            'counterparty_active': counterparty?['is_active'] ?? false,
            'price_id': price['id'],
            'general_material_id': price['general_material_id'],
            'general_material_code': general?['code'] ?? '',
            'general_material_name': general?['name'] ?? '',
            'commercial_material_id': price['commercial_material_id'],
            'commercial_material_code': commercial?['code'] ?? '',
            'commercial_material_name': commercial?['name'] ?? '',
            'material_alias_id': price['material_alias_id'],
            'material_alias_label': alias?['label'] ?? '',
            'material_label_snapshot': price['material_label_snapshot'] ?? '',
            'final_price': price['final_price'],
            'price_active': price['is_active'] ?? false,
            'notes': price['notes'],
            'created_at': price['created_at'],
            'updated_at': price['updated_at'],
          };
        })
        .toList(growable: false);

    rows.sort((a, b) {
      final activeCompare = ((b['counterparty_active'] == true) ? 1 : 0)
          .compareTo((a['counterparty_active'] == true) ? 1 : 0);
      if (activeCompare != 0) return activeCompare;
      final byName = _normalizeName(
        (a['counterparty_name'] ?? '').toString(),
      ).compareTo(_normalizeName((b['counterparty_name'] ?? '').toString()));
      if (byName != 0) return byName;
      return _normalizeName(
        (a['material_label_snapshot'] ?? '').toString(),
      ).compareTo(
        _normalizeName((b['material_label_snapshot'] ?? '').toString()),
      );
    });

    return rows;
  }

  bool _isActive(Map<String, dynamic> row, {String key = 'is_active'}) {
    final value = row[key];
    if (value is bool) return value;
    return value == true;
  }

  String? _siteLabel(String? siteId) {
    if (siteId == null || siteId.isEmpty) return null;
    for (final row in _sites) {
      if ((row['id'] ?? '').toString() == siteId) {
        return (row['name'] ?? '').toString();
      }
    }
    return null;
  }

  String? _generalMaterialLabel(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final row in _generalMaterials) {
      if ((row['id'] ?? '').toString() == id) {
        return (row['name'] ?? '').toString();
      }
    }
    return null;
  }

  String? _commercialMaterialLabel(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final row in _commercialMaterials) {
      if ((row['id'] ?? '').toString() == id) {
        return (row['name'] ?? '').toString();
      }
    }
    return null;
  }

  String _resolvePriceMaterialLabel({
    String? generalMaterialId,
    String? commercialMaterialId,
    String? materialAliasId,
    String? fallback,
  }) {
    final commercialLabel = _commercialMaterialLabel(commercialMaterialId);
    if (commercialLabel != null && commercialLabel.isNotEmpty) {
      return commercialLabel;
    }

    final generalLabel = _generalMaterialLabel(generalMaterialId);
    if (generalLabel != null && generalLabel.isNotEmpty) {
      return generalLabel;
    }

    if (materialAliasId != null && materialAliasId.isNotEmpty) {
      for (final row in _materialAliases) {
        if ((row['id'] ?? '').toString() == materialAliasId) {
          final label = (row['label'] ?? '').toString().trim();
          if (label.isNotEmpty) return label;
        }
      }
    }

    return _normalizeName(fallback ?? '');
  }

  List<_CatalogKeyboardActionRow> _buildKeyboardRows({
    required List<Map<String, dynamic>> counterpartyRows,
    required List<Map<String, dynamic>> generalRows,
    required List<Map<String, dynamic>> commercialRows,
    required List<Map<String, dynamic>> priceRows,
  }) {
    switch (_activeTabIndex) {
      case 0:
        return counterpartyRows
            .map(
              (row) => _CatalogKeyboardActionRow(
                key: 'cp:${(row['id'] ?? '').toString()}',
                active: _isActive(row),
                onEdit: () =>
                    _startInlineEdit('cp:${(row['id'] ?? '').toString()}'),
                onToggleActive: () => _setActive(
                  table: 'men_counterparties',
                  id: (row['id'] ?? '').toString(),
                  isActive: !_isActive(row),
                  successLabel: _isActive(row)
                      ? 'Contraparte desactivada'
                      : 'Contraparte activada',
                ),
                onDelete: () => _deleteRow(
                  table: 'men_counterparties',
                  id: (row['id'] ?? '').toString(),
                  title: 'Eliminar contraparte',
                  label: (row['name'] ?? '').toString(),
                ),
              ),
            )
            .toList(growable: false);
      case 1:
        return [
          ...generalRows.map(
            (row) => _CatalogKeyboardActionRow(
              key: 'matg:${(row['id'] ?? '').toString()}',
              active: _isActive(row),
              onEdit: () =>
                  _startInlineEdit('matg:${(row['id'] ?? '').toString()}'),
              onToggleActive: () => _setActive(
                table: 'material_general_catalog_v2',
                id: (row['id'] ?? '').toString(),
                isActive: !_isActive(row),
                successLabel: _isActive(row)
                    ? 'Material general desactivado'
                    : 'Material general activado',
              ),
              onDelete: () => _deleteRow(
                table: 'material_general_catalog_v2',
                id: (row['id'] ?? '').toString(),
                title: 'Eliminar material general',
                label: (row['name'] ?? '').toString(),
              ),
            ),
          ),
          ...commercialRows.map(
            (row) => _CatalogKeyboardActionRow(
              key: 'matc:${(row['id'] ?? '').toString()}',
              active: _isActive(row),
              onEdit: () =>
                  _startInlineEdit('matc:${(row['id'] ?? '').toString()}'),
              onToggleActive: () => _setActive(
                table: 'material_commercial_catalog_v2',
                id: (row['id'] ?? '').toString(),
                isActive: !_isActive(row),
                successLabel: _isActive(row)
                    ? 'Material comercial desactivado'
                    : 'Material comercial activado',
              ),
              onDelete: () => _deleteRow(
                table: 'material_commercial_catalog_v2',
                id: (row['id'] ?? '').toString(),
                title: 'Eliminar material comercial',
                label: (row['name'] ?? '').toString(),
              ),
            ),
          ),
        ];
      default:
        return priceRows
            .map(
              (row) => _CatalogKeyboardActionRow(
                key: 'price:${(row['price_id'] ?? '').toString()}',
                active: _isActive(row, key: 'price_active'),
                onEdit: () => _startInlineEdit(
                  'price:${(row['price_id'] ?? '').toString()}',
                ),
                onToggleActive: () => _setActive(
                  table: 'men_counterparty_material_prices',
                  id: (row['price_id'] ?? '').toString(),
                  isActive: !_isActive(row, key: 'price_active'),
                  successLabel: _isActive(row, key: 'price_active')
                      ? 'Precio desactivado'
                      : 'Precio activado',
                ),
                onDelete: () => _deleteRow(
                  table: 'men_counterparty_material_prices',
                  id: (row['price_id'] ?? '').toString(),
                  title: 'Eliminar precio',
                  label:
                      '${(row['counterparty_name'] ?? '').toString()} · ${(row['material_label_snapshot'] ?? '').toString()}',
                ),
              ),
            )
            .toList(growable: false);
    }
  }

  KeyEventResult _handleGridKeyEvent(
    KeyEvent event,
    List<_CatalogKeyboardActionRow> rows,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (rows.isEmpty) return KeyEventResult.ignored;

    final index = rows.indexWhere((row) => row.key == _selectedRowKey);
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_multiEditMode) {
        _cancelMultiEdit();
        return KeyEventResult.handled;
      }
      if (_editingRowKey != null) {
        _cancelInlineEdit();
        return KeyEventResult.handled;
      }
      if (_selectedCount > 0) {
        _clearSelection();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final nextIndex = index < 0 ? 0 : (index + 1).clamp(0, rows.length - 1);
      final nextKey = rows[nextIndex].key;
      if (_isShiftPressed()) {
        _selectRowRangeTo(nextKey, rows.map((row) => row.key).toList());
      } else {
        _selectSingleRow(nextKey);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (index <= 0 && !_isShiftPressed()) {
        _focusInsertRowStart();
        return KeyEventResult.handled;
      }
      final nextIndex = index <= 0 ? 0 : index - 1;
      final nextKey = rows[nextIndex].key;
      if (_isShiftPressed()) {
        _selectRowRangeTo(nextKey, rows.map((row) => row.key).toList());
      } else {
        _selectSingleRow(nextKey);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_selectedCount > 1) {
        _startMultiEdit();
        return KeyEventResult.handled;
      }
      final selected = _selectedKeyboardRows(rows);
      final target = selected.isNotEmpty
          ? selected.last
          : index < 0
          ? rows.first
          : rows[index];
      target.onEdit();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      final selected = _selectedKeyboardRows(rows);
      final targets = selected.isNotEmpty
          ? selected
          : [index < 0 ? rows.first : rows[index]];
      for (final target in targets) {
        target.onToggleActive();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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

  Set<String> _currentSelectionKeys() {
    final keys = <String>{..._bulkSelectedRowKeys};
    if (_selectedRowKey != null) keys.add(_selectedRowKey!);
    return keys;
  }

  int get _selectedCount => _currentSelectionKeys().length;

  List<_CatalogKeyboardActionRow> _selectedKeyboardRows(
    List<_CatalogKeyboardActionRow> rows,
  ) {
    final selectedKeys = _currentSelectionKeys();
    if (selectedKeys.isEmpty) return const [];
    return rows.where((row) => selectedKeys.contains(row.key)).toList();
  }

  void _clearSelection() {
    if (!mounted) return;
    setState(() {
      _selectedRowKey = null;
      _selectionAnchorRowKey = null;
      _bulkSelectedRowKeys.clear();
      _multiEditMode = false;
    });
  }

  void _requestGridRowsFocus() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _gridRowsFocusNode.requestFocus();
    });
  }

  void _selectSingleRow(String rowKey) {
    if (!mounted) return;
    setState(() {
      _selectedRowKey = rowKey;
      _selectionAnchorRowKey = rowKey;
      _bulkSelectedRowKeys.clear();
    });
  }

  void _selectRowToggle(String rowKey) {
    if (!mounted) return;
    setState(() {
      if (_bulkSelectedRowKeys.contains(rowKey)) {
        _bulkSelectedRowKeys.remove(rowKey);
        if (_selectedRowKey == rowKey) {
          _selectedRowKey = _bulkSelectedRowKeys.isEmpty
              ? null
              : _bulkSelectedRowKeys.last;
        }
        if (_selectionAnchorRowKey == rowKey) {
          _selectionAnchorRowKey = _selectedRowKey;
        }
        return;
      }
      if (_selectedRowKey != null) _bulkSelectedRowKeys.add(_selectedRowKey!);
      _bulkSelectedRowKeys.add(rowKey);
      _selectedRowKey = rowKey;
      _selectionAnchorRowKey ??= rowKey;
    });
  }

  void _selectRowRangeTo(String rowKey, List<String> visibleKeys) {
    if (visibleKeys.isEmpty) return;
    final anchor = _selectionAnchorRowKey ?? _selectedRowKey ?? rowKey;
    final anchorIndex = visibleKeys.indexOf(anchor);
    final targetIndex = visibleKeys.indexOf(rowKey);
    if (anchorIndex == -1 || targetIndex == -1) {
      _selectSingleRow(rowKey);
      return;
    }
    final from = math.min(anchorIndex, targetIndex);
    final to = math.max(anchorIndex, targetIndex);
    final keys = visibleKeys.sublist(from, to + 1).toSet();
    if (!mounted) return;
    setState(() {
      _selectionAnchorRowKey = anchor;
      _selectedRowKey = rowKey;
      _bulkSelectedRowKeys
        ..clear()
        ..addAll(keys);
    });
  }

  void _handleRowSelection(String rowKey, List<String> visibleKeys) {
    if (_editingRowKey != null || _multiEditMode) return;
    if (_isShiftPressed()) {
      _selectRowRangeTo(rowKey, visibleKeys);
      _requestGridRowsFocus();
      return;
    }
    if (_isCtrlOrCmdPressed()) {
      _selectRowToggle(rowKey);
      _requestGridRowsFocus();
      return;
    }
    _selectSingleRow(rowKey);
    _requestGridRowsFocus();
  }

  void _handleRowSecondarySelection(String rowKey, List<String> visibleKeys) {
    if (_currentSelectionKeys().contains(rowKey)) return;
    _selectSingleRow(rowKey);
    _requestGridRowsFocus();
    if (!visibleKeys.contains(rowKey)) return;
  }

  void _focusFirstVisibleRow(List<String> visibleKeys) {
    if (visibleKeys.isEmpty) return;
    FocusScope.of(context).unfocus();
    _selectSingleRow(visibleKeys.first);
    _requestGridRowsFocus();
  }

  void _beginDragSelection(String rowKey, List<String> visibleKeys) {
    if (_editingRowKey != null || _multiEditMode) return;
    _dragSelectionActive = true;
    _dragSelectionVisibleKeys = visibleKeys;
    _selectSingleRow(rowKey);
    _requestGridRowsFocus();
  }

  void _updateDragSelection(String rowKey) {
    if (!_dragSelectionActive ||
        _editingRowKey != null ||
        _multiEditMode ||
        _dragSelectionVisibleKeys.isEmpty) {
      return;
    }
    _selectRowRangeTo(rowKey, _dragSelectionVisibleKeys);
  }

  void _endDragSelection() {
    _dragSelectionActive = false;
    _dragSelectionVisibleKeys = const <String>[];
  }

  void _focusInsertRowStart() {
    _clearSelection();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (_activeTabIndex) {
        case 0:
          _counterpartyDraftNameFocus.requestFocus();
          break;
        case 1:
          _materialDraftLevelFocus.requestFocus();
          break;
        default:
          _priceDraftCounterpartyFocus.requestFocus();
          break;
      }
    });
  }

  KeyEventResult _handleInsertTextNavigation({
    required KeyEvent event,
    required TextEditingController controller,
    FocusNode? previous,
    FocusNode? next,
    VoidCallback? onDown,
  }) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final selection = controller.selection;
    final atStart = selection.isValid && selection.start <= 0;
    final atEnd = selection.isValid && selection.end >= controller.text.length;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
        previous != null &&
        atStart) {
      previous.requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
        next != null &&
        atEnd) {
      next.requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && onDown != null) {
      onDown();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _startMultiEdit() {
    if (!mounted || _selectedCount <= 1) return;
    setState(() {
      _editingRowKey = null;
      _multiEditMode = true;
    });
  }

  void _cancelMultiEdit() {
    if (!mounted) return;
    setState(() => _multiEditMode = false);
  }

  bool _isMultiContextRow(String rowKey) {
    return _selectedCount > 1 && _currentSelectionKeys().contains(rowKey);
  }

  Future<void> _deleteSelectedRows(List<_CatalogKeyboardActionRow> rows) async {
    final selected = _selectedKeyboardRows(rows);
    if (selected.isEmpty) return;
    for (final row in selected) {
      if (row.onDelete != null) {
        await row.onDelete!.call();
      }
    }
  }

  Future<String?> _writeDownloadsFile(String fileName, String content) =>
      saveCsvFile(
        fileName: fileName,
        content: content,
        dialogTitle: 'Guardar CSV de menudeo',
      );

  Future<void> _exportCurrentTabCsv({
    required List<Map<String, dynamic>> counterpartyRows,
    required List<Map<String, dynamic>> generalRows,
    required List<Map<String, dynamic>> commercialRows,
    required List<Map<String, dynamic>> priceRows,
  }) async {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    late final List<String> headers;
    late final List<List<String>> data;
    late final String slug;

    switch (_activeTabIndex) {
      case 0:
        slug = 'contrapartes';
        headers = ['nombre', 'tipo', 'grupo', 'empresa', 'activo', 'notas'];
        data = counterpartyRows
            .map(
              (row) => [
                (row['name'] ?? '').toString(),
                (row['kind'] ?? '').toString(),
                (row['group_code'] ?? '').toString(),
                _siteLabel(row['site_id']?.toString()) ?? '',
                _isActive(row) ? 'SI' : 'NO',
                (row['notes'] ?? '').toString(),
              ],
            )
            .toList(growable: false);
        break;
      case 1:
        slug = 'materiales';
        headers = ['nivel', 'codigo', 'nombre', 'familia', 'general', 'activo'];
        data = [
          ...generalRows.map(
            (row) => [
              'GENERAL',
              (row['code'] ?? '').toString(),
              (row['name'] ?? '').toString(),
              '',
              '',
              _isActive(row) ? 'SI' : 'NO',
            ],
          ),
          ...commercialRows.map(
            (row) => [
              'COMERCIAL',
              (row['code'] ?? '').toString(),
              (row['name'] ?? '').toString(),
              (row['family'] ?? '').toString(),
              _generalMaterialLabel(row['general_material_id']?.toString()) ??
                  '',
              _isActive(row) ? 'SI' : 'NO',
            ],
          ),
        ];
        break;
      default:
        slug = 'precios';
        headers = [
          'contraparte',
          'grupo',
          'material',
          'precio',
          'activo',
          'notas',
        ];
        data = priceRows
            .map(
              (row) => [
                (row['counterparty_name'] ?? '').toString(),
                (row['group_code'] ?? '').toString(),
                (row['material_label_snapshot'] ?? '').toString(),
                (row['final_price'] ?? '').toString(),
                _isActive(row, key: 'price_active') ? 'SI' : 'NO',
                (row['notes'] ?? '').toString(),
              ],
            )
            .toList(growable: false);
        break;
    }

    final sb = StringBuffer()
      ..write('\uFEFF')
      ..writeln(headers.join(','));
    for (final row in data) {
      sb.writeln(row.map(_csvEscape).join(','));
    }
    final path = await _writeDownloadsFile(
      'menudeo_${slug}_$stamp.csv',
      sb.toString(),
    );
    _toast(
      path == null
          ? 'No se pudo guardar CSV en Descargas'
          : 'CSV exportado en: $path',
    );
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    final needsQuotes =
        escaped.contains(',') ||
        escaped.contains('\n') ||
        escaped.contains('"');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  InventoryGridTopBarData _buildTopBarData({
    required List<Map<String, dynamic>> counterpartyRows,
    required List<Map<String, dynamic>> generalRows,
    required List<Map<String, dynamic>> commercialRows,
    required List<Map<String, dynamic>> priceRows,
  }) {
    switch (_activeTabIndex) {
      case 0:
        return InventoryGridTopBarData(
          metricIcon: Icons.groups_rounded,
          metricLabel: 'CONTRAPARTES',
          metricValue: '${counterpartyRows.length}',
          metricSubtitle: 'Filtrado (${counterpartyRows.length} registros)',
          exportingCsv: false,
          gridEditMode: false,
          canToggleGridEdit: false,
          canDeleteSelection: _selectedCount > 0,
          deletingSelection: false,
          selectedCount: _selectedCount,
          onExportCsv: () => unawaited(
            _exportCurrentTabCsv(
              counterpartyRows: counterpartyRows,
              generalRows: generalRows,
              commercialRows: commercialRows,
              priceRows: priceRows,
            ),
          ),
          onDeleteSelection: () => _deleteSelectedRows(
            _buildKeyboardRows(
              counterpartyRows: counterpartyRows,
              generalRows: generalRows,
              commercialRows: commercialRows,
              priceRows: priceRows,
            ),
          ),
        );
      case 1:
        final total = generalRows.length + commercialRows.length;
        return InventoryGridTopBarData(
          metricIcon: Icons.inventory_2_rounded,
          metricLabel: 'MATERIALES',
          metricValue: '$total',
          metricSubtitle: 'Filtrado ($total registros)',
          exportingCsv: false,
          gridEditMode: false,
          canToggleGridEdit: false,
          canDeleteSelection: _selectedCount > 0,
          deletingSelection: false,
          selectedCount: _selectedCount,
          onExportCsv: () => unawaited(
            _exportCurrentTabCsv(
              counterpartyRows: counterpartyRows,
              generalRows: generalRows,
              commercialRows: commercialRows,
              priceRows: priceRows,
            ),
          ),
          onDeleteSelection: () => _deleteSelectedRows(
            _buildKeyboardRows(
              counterpartyRows: counterpartyRows,
              generalRows: generalRows,
              commercialRows: commercialRows,
              priceRows: priceRows,
            ),
          ),
        );
      default:
        return InventoryGridTopBarData(
          metricIcon: Icons.price_change_rounded,
          metricLabel: 'PRECIOS',
          metricValue: '${priceRows.length}',
          metricSubtitle: 'Filtrado (${priceRows.length} registros)',
          exportingCsv: false,
          gridEditMode: false,
          canToggleGridEdit: false,
          canDeleteSelection: _selectedCount > 0,
          deletingSelection: false,
          selectedCount: _selectedCount,
          onExportCsv: () => unawaited(
            _exportCurrentTabCsv(
              counterpartyRows: counterpartyRows,
              generalRows: generalRows,
              commercialRows: commercialRows,
              priceRows: priceRows,
            ),
          ),
          onDeleteSelection: () => _deleteSelectedRows(
            _buildKeyboardRows(
              counterpartyRows: counterpartyRows,
              generalRows: generalRows,
              commercialRows: commercialRows,
              priceRows: priceRows,
            ),
          ),
        );
    }
  }

  bool _hasActiveFilter(String columnId) {
    final values = _columnValueFilters[columnId];
    return values != null && values.isNotEmpty;
  }

  bool _matchesColumnFilters(
    Map<String, dynamic> row,
    Map<String, String> values,
  ) {
    for (final entry in _columnValueFilters.entries) {
      if (entry.value.isEmpty) continue;
      final cell = _normalizeName(values[entry.key] ?? '');
      if (!entry.value.contains(cell)) return false;
    }
    return true;
  }

  Future<void> _openColumnFilter({
    required String columnId,
    required String title,
    required List<String> values,
  }) async {
    final normalizedValues =
        values
            .map(_normalizeName)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final options = normalizedValues
        .map(
          (value) => _MenudeoPickerOption<String>(value: value, label: value),
        )
        .toList(growable: false);
    final selected = await _showMenudeoMultiSelectDialog(
      context,
      title: title,
      options: options,
      initialValues: _columnValueFilters[columnId] ?? <String>{},
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (selected.isEmpty) {
        _columnValueFilters.remove(columnId);
      } else {
        _columnValueFilters[columnId] = selected;
      }
      _selectedRowKey = null;
      _selectionAnchorRowKey = null;
      _bulkSelectedRowKeys.clear();
    });
  }

  Future<void> _setActive({
    required String table,
    required String id,
    required bool isActive,
    required String successLabel,
  }) async {
    try {
      await _supa.from(table).update({'is_active': isActive}).eq('id', id);
      _toast(successLabel);
      await _loadAll(showLoader: false);
    } on PostgrestException catch (e) {
      _toast('No se pudo actualizar el registro: ${e.message}');
    }
  }

  Future<void> _deleteRow({
    required String table,
    required String id,
    required String title,
    required String label,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContractConfirmDialogKeyHandler(
        onCancel: () => Navigator.pop(dialogContext, false),
        onConfirm: () => Navigator.pop(dialogContext, true),
        child: AlertDialog(
          title: Text(title),
          content: Text('¿Seguro que deseas eliminar "$label"?'),
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
    try {
      await _supa.from(table).delete().eq('id', id);
      _toast('Registro eliminado');
      await _loadAll(showLoader: false);
    } on PostgrestException catch (e) {
      _toast('No se pudo eliminar el registro: ${e.message}');
    }
  }

  void _startInlineEdit(String rowKey) {
    setState(() {
      _multiEditMode = false;
      _selectedRowKey = rowKey;
      _editingRowKey = rowKey;
    });
  }

  void _cancelInlineEdit() {
    if (!mounted) return;
    setState(() => _editingRowKey = null);
  }

  Future<void> _saveCounterpartyInline(
    Map<String, dynamic> existing,
    Map<String, dynamic> payload,
  ) async {
    if ((payload['name'] ?? '').toString().trim().isEmpty ||
        (payload['group_code'] ?? '').toString().trim().isEmpty) {
      _toast('Nombre y grupo son obligatorios');
      return;
    }
    try {
      await _supa
          .from('men_counterparties')
          .update(payload)
          .eq('id', existing['id']);
      if (!mounted) return;
      setState(() => _editingRowKey = null);
      _toast('Contraparte actualizada');
      await _loadAll(showLoader: false);
    } on PostgrestException catch (e) {
      _toast('No se pudo guardar la contraparte: ${e.message}');
    }
  }

  Future<void> _savePriceInline(
    Map<String, dynamic> existing,
    Map<String, dynamic> payload,
  ) async {
    final price = payload['final_price'];
    final hasCounterparty = (payload['counterparty_id'] ?? '')
        .toString()
        .trim()
        .isNotEmpty;
    final hasMaterial =
        (payload['general_material_id'] ?? '').toString().trim().isNotEmpty ||
        (payload['commercial_material_id'] ?? '').toString().trim().isNotEmpty;
    if (!hasCounterparty || !hasMaterial || price == null) {
      _toast('Contraparte, material y precio son obligatorios');
      return;
    }
    try {
      await _supa
          .from('men_counterparty_material_prices')
          .update(payload)
          .eq('id', existing['price_id']);
      if (!mounted) return;
      setState(() => _editingRowKey = null);
      _toast('Precio actualizado');
      await _loadAll(showLoader: false);
    } on PostgrestException catch (e) {
      _toast('No se pudo guardar el precio: ${e.message}');
    }
  }

  Future<void> _saveGeneralMaterialInline(
    Map<String, dynamic> existing,
    Map<String, dynamic> payload,
  ) async {
    final name = (payload['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      _toast('El nombre del material es obligatorio');
      return;
    }
    try {
      await _supa
          .from('material_general_catalog_v2')
          .update({
            'name': name,
            'code': _materialCodeFromName(name),
            'notes': payload['notes'],
            'is_active': payload['is_active'],
          })
          .eq('id', existing['id']);
      if (!mounted) return;
      setState(() => _editingRowKey = null);
      _toast('Material general actualizado');
      await _loadAll(showLoader: false);
    } on PostgrestException catch (e) {
      _toast('No se pudo guardar el material general: ${e.message}');
    }
  }

  Future<void> _saveCommercialMaterialInline(
    Map<String, dynamic> existing,
    Map<String, dynamic> payload,
  ) async {
    final name = (payload['name'] ?? '').toString().trim();
    final generalMaterialId = (payload['general_material_id'] ?? '')
        .toString()
        .trim();
    if (name.isEmpty || generalMaterialId.isEmpty) {
      _toast('Nombre y material general son obligatorios');
      return;
    }
    try {
      await _supa
          .from('material_commercial_catalog_v2')
          .update({
            'name': name,
            'code': _materialCodeFromName(name),
            'family': payload['family'],
            'general_material_id': generalMaterialId,
            'notes': payload['notes'],
            'is_active': payload['is_active'],
          })
          .eq('id', existing['id']);
      if (!mounted) return;
      setState(() => _editingRowKey = null);
      _toast('Material comercial actualizado');
      await _loadAll(showLoader: false);
    } on PostgrestException catch (e) {
      _toast('No se pudo guardar el material comercial: ${e.message}');
    }
  }

  Future<void> _saveCounterpartySelection(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> payload,
  ) async {
    if (rows.isEmpty) return;
    try {
      for (final row in rows) {
        final rowPayload = <String, dynamic>{'is_active': payload['is_active']};
        if ((payload['group_code'] ?? '').toString().trim().isNotEmpty) {
          rowPayload['group_code'] = payload['group_code'];
        }
        if ((payload['notes'] ?? '').toString().trim().isNotEmpty) {
          rowPayload['notes'] = payload['notes'];
        }
        await _supa
            .from('men_counterparties')
            .update(rowPayload)
            .eq('id', row['id']);
      }
      if (!mounted) return;
      setState(() => _multiEditMode = false);
      _toast('Selección de contrapartes actualizada');
      await _loadAll(showLoader: false);
    } on PostgrestException catch (e) {
      _toast('No se pudo guardar la selección: ${e.message}');
    }
  }

  Future<void> _saveMaterialsSelection(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> payload,
  ) async {
    if (rows.isEmpty) return;
    try {
      for (final row in rows) {
        final table = row['_level'] == 'GENERAL'
            ? 'material_general_catalog_v2'
            : 'material_commercial_catalog_v2';
        final rowPayload = <String, dynamic>{'is_active': payload['is_active']};
        if ((payload['notes'] ?? '').toString().trim().isNotEmpty) {
          rowPayload['notes'] = payload['notes'];
        }
        await _supa.from(table).update(rowPayload).eq('id', row['id']);
      }
      if (!mounted) return;
      setState(() => _multiEditMode = false);
      _toast('Selección de materiales actualizada');
      await _loadAll(showLoader: false);
    } on PostgrestException catch (e) {
      _toast('No se pudo guardar la selección: ${e.message}');
    }
  }

  Future<void> _savePricesSelection(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> payload,
  ) async {
    if (rows.isEmpty) return;
    final rawPrice = (payload['final_price'] ?? '').toString().trim();
    final parsedPrice = rawPrice.isEmpty ? null : double.tryParse(rawPrice);
    if (rawPrice.isNotEmpty && parsedPrice == null) {
      _toast('El precio debe ser numérico');
      return;
    }
    try {
      for (final row in rows) {
        final rowPayload = <String, dynamic>{'is_active': payload['is_active']};
        if (parsedPrice != null) {
          rowPayload['final_price'] = parsedPrice;
        }
        if ((payload['notes'] ?? '').toString().trim().isNotEmpty) {
          rowPayload['notes'] = payload['notes'];
        }
        await _supa
            .from('men_counterparty_material_prices')
            .update(rowPayload)
            .eq('id', row['price_id']);
      }
      if (!mounted) return;
      setState(() => _multiEditMode = false);
      _toast('Selección de precios actualizada');
      await _loadAll(showLoader: false);
    } on PostgrestException catch (e) {
      _toast('No se pudo guardar la selección: ${e.message}');
    }
  }

  void _resetCounterpartyDraft() {
    _counterpartyDraftNameC.clear();
    _counterpartyDraftGroupC.text = 'GENERAL';
    _counterpartyDraftNotesC.clear();
    _counterpartyDraftKind = 'supplier';
    _counterpartyDraftSiteId = null;
  }

  void _resetMaterialDraft() {
    _materialDraftNameC.clear();
    _materialDraftNotesC.clear();
    _materialDraftLevel = 'GENERAL';
    _materialDraftFamily = 'other';
    _materialDraftGeneralMaterialId = null;
  }

  Future<void> _insertMaterialInline() async {
    if (_insertingMaterial) return;
    final name = _normalizeName(_materialDraftNameC.text);
    if (name.isEmpty) {
      _toast('El nombre del material es obligatorio');
      return;
    }
    if (_materialDraftLevel == 'COMERCIAL' &&
        (_materialDraftGeneralMaterialId ?? '').isEmpty) {
      _toast('Debes seleccionar un material general relacionado');
      return;
    }
    setState(() => _insertingMaterial = true);
    try {
      if (_materialDraftLevel == 'GENERAL') {
        await _supa.from('material_general_catalog_v2').insert({
          'name': name,
          'code': _materialCodeFromName(name),
          'notes': _materialDraftNotesC.text.trim().isEmpty
              ? null
              : _materialDraftNotesC.text.trim(),
          'is_active': true,
        });
        _toast('Material general agregado');
      } else {
        await _supa.from('material_commercial_catalog_v2').insert({
          'name': name,
          'code': _materialCodeFromName(name),
          'family': _materialDraftFamily,
          'general_material_id': _materialDraftGeneralMaterialId,
          'classification_kind': 'classified_stock',
          'flow_scope': 'BOTH',
          'tracks_patio_stock': true,
          'allows_direct_entry': true,
          'allows_transformation_output': true,
          'allows_sale': true,
          'notes': _materialDraftNotesC.text.trim().isEmpty
              ? null
              : _materialDraftNotesC.text.trim(),
          'is_active': true,
        });
        _toast('Material comercial agregado');
      }
      _resetMaterialDraft();
      await _loadAll(showLoader: false);
    } on PostgrestException catch (e) {
      _toast('No se pudo guardar el material: ${e.message}');
    } finally {
      if (mounted) setState(() => _insertingMaterial = false);
    }
  }

  Future<void> _insertCounterpartyInline() async {
    if (_insertingCounterparty) return;
    final name = _normalizeName(_counterpartyDraftNameC.text);
    final groupCode = _normalizeName(_counterpartyDraftGroupC.text);
    if (name.isEmpty || groupCode.isEmpty) {
      _toast('Nombre y grupo son obligatorios');
      return;
    }
    setState(() => _insertingCounterparty = true);
    try {
      await _supa.from('men_counterparties').insert({
        'name': name,
        'kind': _counterpartyDraftKind,
        'group_code': groupCode,
        'site_id': _counterpartyDraftSiteId,
        'notes': _counterpartyDraftNotesC.text.trim().isEmpty
            ? null
            : _counterpartyDraftNotesC.text.trim(),
        'is_active': true,
      });
      _resetCounterpartyDraft();
      _toast('Contraparte agregada');
      await _loadAll(showLoader: false);
    } on PostgrestException catch (e) {
      _toast('No se pudo guardar la contraparte: ${e.message}');
    } finally {
      if (mounted) setState(() => _insertingCounterparty = false);
    }
  }

  void _resetPriceDraft() {
    _priceDraftCounterpartyId = null;
    _priceDraftGeneralMaterialId = null;
    _priceDraftCommercialMaterialId = null;
    _priceDraftAmountC.clear();
    _priceDraftNotesC.clear();
  }

  Future<void> _insertPriceInline() async {
    if (_insertingPrice) return;
    final price = double.tryParse(_priceDraftAmountC.text.trim());
    final materialLabel = _resolvePriceMaterialLabel(
      generalMaterialId: _priceDraftGeneralMaterialId,
      commercialMaterialId: _priceDraftCommercialMaterialId,
      materialAliasId: null,
      fallback: '',
    );
    if ((_priceDraftCounterpartyId ?? '').isEmpty ||
        materialLabel.isEmpty ||
        price == null) {
      _toast('Contraparte, material y precio son obligatorios');
      return;
    }
    if ((_priceDraftGeneralMaterialId ?? '').isEmpty &&
        (_priceDraftCommercialMaterialId ?? '').isEmpty) {
      _toast('Selecciona un material general o comercial');
      return;
    }
    setState(() => _insertingPrice = true);
    try {
      await _supa.from('men_counterparty_material_prices').insert({
        'counterparty_id': _priceDraftCounterpartyId,
        'general_material_id': _priceDraftGeneralMaterialId,
        'commercial_material_id': _priceDraftCommercialMaterialId,
        'material_label_snapshot': materialLabel,
        'final_price': price,
        'notes': _priceDraftNotesC.text.trim().isEmpty
            ? null
            : _priceDraftNotesC.text.trim(),
        'is_active': true,
      });
      _resetPriceDraft();
      _toast('Precio agregado');
      await _loadAll(showLoader: false);
    } on PostgrestException catch (e) {
      _toast('No se pudo guardar el precio: ${e.message}');
    } finally {
      if (mounted) setState(() => _insertingPrice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: menudeoAreaTokens,
      child: AppShell(
        background: const _MenudeoCatalogBackground(),
        wrapBodyInGlass: false,
        animateHeaderSlots: false,
        headerBodySpacing: 6,
        padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
        leadingBuilder: (_, _) => _CatalogHeaderButton(
          label: 'Menudeo',
          icon: Icons.arrow_back_rounded,
          onTap: _goBack,
        ),
        centerBuilder: (_, animation) => _CatalogBrand(
          contentAnim: animation,
          title: 'Contrapartes y precios',
        ),
        trailingBuilder: (_, _) => _CatalogHeaderButton(
          label: 'Cerrar sesión',
          icon: Icons.logout_rounded,
          onTap: _logout,
        ),
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: ContractGlassCard(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 42),
                const SizedBox(height: 12),
                const Text(
                  'No se pudo cargar Menudeo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: contractPrimaryButtonStyle(context),
                  onPressed: _loadAll,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final counterpartyRows = _counterparties
        .where((row) {
          return _matchesColumnFilters(row, {
            'counterparty_name': (row['name'] ?? '').toString(),
            'counterparty_kind': (row['kind'] ?? '').toString(),
            'counterparty_group': (row['group_code'] ?? '').toString(),
            'counterparty_site': _siteLabel(row['site_id']?.toString()) ?? '',
            'counterparty_status': _isActive(row) ? 'ACTIVO' : 'INACTIVO',
          });
        })
        .toList(growable: false);
    final generalRows = _generalMaterials;
    final commercialRows = _commercialMaterials;
    final filteredGeneralRows = generalRows
        .where((row) {
          return _matchesColumnFilters(row, {
            'material_level': 'GENERAL',
            'material_code': (row['code'] ?? '').toString(),
            'material_name': (row['name'] ?? '').toString(),
            'material_family': '',
            'material_relation': 'CATALOGO BASE',
            'material_status': _isActive(row) ? 'ACTIVO' : 'INACTIVO',
          });
        })
        .toList(growable: false);
    final filteredCommercialRows = commercialRows
        .where((row) {
          return _matchesColumnFilters(row, {
            'material_level': 'COMERCIAL',
            'material_code': (row['code'] ?? '').toString(),
            'material_name': (row['name'] ?? '').toString(),
            'material_family': (row['family'] ?? '').toString(),
            'material_relation':
                _generalMaterialLabel(row['general_material_id']?.toString()) ??
                '',
            'material_status': _isActive(row) ? 'ACTIVO' : 'INACTIVO',
          });
        })
        .toList(growable: false);
    final priceRows = _prices
        .where((row) {
          if (!_showInactive &&
              (!_isActive(row, key: 'counterparty_active') ||
                  !_isActive(row, key: 'price_active'))) {
            return false;
          }
          return _matchesColumnFilters(row, {
            'price_counterparty': (row['counterparty_name'] ?? '').toString(),
            'price_group': (row['group_code'] ?? '').toString(),
            'price_material': (row['material_label_snapshot'] ?? '').toString(),
            'price_amount': (row['final_price'] ?? '').toString(),
            'price_status': _isActive(row, key: 'price_active')
                ? 'ACTIVO'
                : 'INACTIVO',
          });
        })
        .toList(growable: false);
    final keyboardRows = _buildKeyboardRows(
      counterpartyRows: counterpartyRows,
      generalRows: generalRows,
      commercialRows: commercialRows,
      priceRows: priceRows,
    );
    final keyboardKeys = keyboardRows.map((row) => row.key).toSet();
    final invalidBulkSelection = _bulkSelectedRowKeys.any(
      (key) => !keyboardKeys.contains(key),
    );
    if ((_selectedRowKey != null && !keyboardKeys.contains(_selectedRowKey)) ||
        invalidBulkSelection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final stillInvalidPrimary =
            _selectedRowKey != null && !keyboardKeys.contains(_selectedRowKey);
        final stillInvalidBulk = _bulkSelectedRowKeys.any(
          (key) => !keyboardKeys.contains(key),
        );
        if (stillInvalidPrimary || stillInvalidBulk) {
          setState(() {
            if (stillInvalidPrimary) {
              _selectedRowKey = null;
              _selectionAnchorRowKey = null;
            }
            _bulkSelectedRowKeys.removeWhere(
              (key) => !keyboardKeys.contains(key),
            );
          });
        }
      });
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(56, 0, 6, 0),
          child: Focus(
            focusNode: _gridRowsFocusNode,
            autofocus: true,
            onKeyEvent: (_, event) => _handleGridKeyEvent(event, keyboardRows),
            child: DefaultTabController(
              length: 3,
              initialIndex: _activeTabIndex,
              child: Builder(
                builder: (context) {
                  final controller = DefaultTabController.of(context);
                  return AnimatedBuilder(
                    animation: controller.animation!,
                    builder: (context, _) {
                      final currentIndex = controller.index;
                      if (_activeTabIndex != currentIndex) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _activeTabIndex != currentIndex) {
                            setState(() {
                              _activeTabIndex = currentIndex;
                              _selectedRowKey = null;
                              _selectionAnchorRowKey = null;
                              _bulkSelectedRowKeys.clear();
                              _multiEditMode = false;
                            });
                            _focusInsertRowStart();
                          }
                        });
                      }

                      final topBarData = _buildTopBarData(
                        counterpartyRows: counterpartyRows,
                        generalRows: filteredGeneralRows,
                        commercialRows: filteredCommercialRows,
                        priceRows: priceRows,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
                            child: InventoryGridTopBar(data: topBarData),
                          ),
                          AppFolderTabs(
                            controller: controller,
                            maxWidth: 760,
                            showBottomRail: false,
                            items: const [
                              AppFolderTabItem(
                                label: 'Contrapartes',
                                icon: Icons.groups_rounded,
                              ),
                              AppFolderTabItem(
                                label: 'Materiales',
                                icon: Icons.inventory_2_rounded,
                              ),
                              AppFolderTabItem(
                                label: 'Precios',
                                icon: Icons.price_change_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: TabBarView(
                              controller: controller,
                              children: [
                                _buildCounterpartiesTab(counterpartyRows),
                                _buildMaterialsTab(
                                  filteredGeneralRows,
                                  filteredCommercialRows,
                                ),
                                _buildPricesTab(priceRows),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounterpartiesTab(List<Map<String, dynamic>> rows) {
    final counterpartyRowKeys = rows
        .map((row) => 'cp:${(row['id'] ?? '').toString()}')
        .toList(growable: false);
    final selectedRows = rows
        .where(
          (row) => _currentSelectionKeys().contains(
            'cp:${(row['id'] ?? '').toString()}',
          ),
        )
        .toList(growable: false);
    return _CatalogTabSurface(
      child: Column(
        children: [
          _CatalogHeaderRow(
            columns: [
              _CatalogHeaderColumn(
                'CONTRAPARTE',
                250,
                active: _hasActiveFilter('counterparty_name'),
                onFilter: () => _openColumnFilter(
                  columnId: 'counterparty_name',
                  title: 'Filtrar contraparte',
                  values: rows
                      .map((row) => (row['name'] ?? '').toString())
                      .toList(),
                ),
              ),
              _CatalogHeaderColumn(
                'TIPO',
                120,
                active: _hasActiveFilter('counterparty_kind'),
                onFilter: () => _openColumnFilter(
                  columnId: 'counterparty_kind',
                  title: 'Filtrar tipo',
                  values: rows
                      .map((row) => (row['kind'] ?? '').toString())
                      .toList(),
                ),
              ),
              _CatalogHeaderColumn(
                'GRUPO',
                140,
                active: _hasActiveFilter('counterparty_group'),
                onFilter: () => _openColumnFilter(
                  columnId: 'counterparty_group',
                  title: 'Filtrar grupo',
                  values: rows
                      .map((row) => (row['group_code'] ?? '').toString())
                      .toList(),
                ),
              ),
              _CatalogHeaderColumn(
                'EMPRESA',
                220,
                active: _hasActiveFilter('counterparty_site'),
                onFilter: () => _openColumnFilter(
                  columnId: 'counterparty_site',
                  title: 'Filtrar empresa',
                  values: rows
                      .map(
                        (row) => _siteLabel(row['site_id']?.toString()) ?? '',
                      )
                      .toList(),
                ),
              ),
              _CatalogHeaderColumn(
                'ESTADO',
                110,
                active: _hasActiveFilter('counterparty_status'),
                onFilter: () => _openColumnFilter(
                  columnId: 'counterparty_status',
                  title: 'Filtrar estado',
                  values: rows
                      .map((row) => _isActive(row) ? 'ACTIVO' : 'INACTIVO')
                      .toList(),
                ),
              ),
              _CatalogHeaderColumn('NOTAS', 260),
              _CatalogHeaderColumn('ACCIONES', _kCatalogActionsW),
            ],
          ),
          const SizedBox(height: 8),
          _CatalogInlineInsertRow(
            contentWidth: _kCounterpartyContentW,
            actionChild: _CatalogInlineAddButton(
              loading: _insertingCounterparty,
              onTap: _insertCounterpartyInline,
            ),
            children: [
              _CatalogInlineFieldCell(
                width: 250,
                child: Focus(
                  onKeyEvent: (_, event) => _handleInsertTextNavigation(
                    event: event,
                    controller: _counterpartyDraftNameC,
                    next: _counterpartyDraftKindFocus,
                    onDown: () => _focusFirstVisibleRow(counterpartyRowKeys),
                  ),
                  child: TextField(
                    controller: _counterpartyDraftNameC,
                    focusNode: _counterpartyDraftNameFocus,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _catalogInlineFieldDecoration(
                      context,
                      'Nueva contraparte',
                    ),
                    onSubmitted: (_) =>
                        _counterpartyDraftKindFocus.requestFocus(),
                  ),
                ),
              ),
              _CatalogInlineFieldCell(
                width: 120,
                child: _CatalogPickerButtonField<String>(
                  focusNode: _counterpartyDraftKindFocus,
                  label: 'Tipo',
                  displayValue: switch (_counterpartyDraftKind) {
                    'supplier' => 'Proveedor',
                    'customer' => 'Cliente',
                    'both' => 'Ambos',
                    _ => _counterpartyDraftKind,
                  },
                  dialogTitle: 'Seleccionar tipo',
                  initialValue: _counterpartyDraftKind,
                  options: const [
                    _MenudeoPickerOption(value: 'supplier', label: 'Proveedor'),
                    _MenudeoPickerOption(value: 'customer', label: 'Cliente'),
                    _MenudeoPickerOption(value: 'both', label: 'Ambos'),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _counterpartyDraftKind = value);
                  },
                  onMovePrev: () => _counterpartyDraftNameFocus.requestFocus(),
                  onMoveNext: () => _counterpartyDraftGroupFocus.requestFocus(),
                  onMoveDown: () => _focusFirstVisibleRow(counterpartyRowKeys),
                  onSelected: () => _counterpartyDraftGroupFocus.requestFocus(),
                ),
              ),
              _CatalogInlineFieldCell(
                width: 140,
                child: Focus(
                  onKeyEvent: (_, event) => _handleInsertTextNavigation(
                    event: event,
                    controller: _counterpartyDraftGroupC,
                    previous: _counterpartyDraftKindFocus,
                    next: _counterpartyDraftSiteFocus,
                    onDown: () => _focusFirstVisibleRow(counterpartyRowKeys),
                  ),
                  child: TextField(
                    controller: _counterpartyDraftGroupC,
                    focusNode: _counterpartyDraftGroupFocus,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _catalogInlineFieldDecoration(context, 'Grupo'),
                    onSubmitted: (_) =>
                        _counterpartyDraftSiteFocus.requestFocus(),
                  ),
                ),
              ),
              _CatalogInlineFieldCell(
                width: 220,
                child: _CatalogPickerButtonField<String?>(
                  focusNode: _counterpartyDraftSiteFocus,
                  label: 'Empresa',
                  displayValue: _siteLabel(_counterpartyDraftSiteId) ?? '',
                  dialogTitle: 'Seleccionar empresa',
                  initialValue: _counterpartyDraftSiteId,
                  allowClear: true,
                  options: _sites
                      .map(
                        (row) => _MenudeoPickerOption<String?>(
                          value: (row['id'] ?? '').toString(),
                          label: (row['name'] ?? '').toString(),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setState(() => _counterpartyDraftSiteId = value),
                  onMovePrev: () => _counterpartyDraftGroupFocus.requestFocus(),
                  onMoveNext: () => _counterpartyDraftNotesFocus.requestFocus(),
                  onMoveDown: () => _focusFirstVisibleRow(counterpartyRowKeys),
                  onSelected: () => _counterpartyDraftNotesFocus.requestFocus(),
                ),
              ),
              const _CatalogInlineFieldCell(
                width: 110,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ACTIVO',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              _CatalogInlineFieldCell(
                width: 260,
                child: Focus(
                  onKeyEvent: (_, event) => _handleInsertTextNavigation(
                    event: event,
                    controller: _counterpartyDraftNotesC,
                    previous: _counterpartyDraftSiteFocus,
                    onDown: () => _focusFirstVisibleRow(counterpartyRowKeys),
                  ),
                  child: TextField(
                    controller: _counterpartyDraftNotesC,
                    focusNode: _counterpartyDraftNotesFocus,
                    decoration: _catalogInlineFieldDecoration(context, 'Notas'),
                    onSubmitted: (_) => _insertCounterpartyInline(),
                  ),
                ),
              ),
            ],
          ),
          if (_multiEditMode && selectedRows.length > 1) ...[
            const SizedBox(height: 8),
            _CounterpartySelectionEditRow(
              selectedCount: selectedRows.length,
              onCancel: _cancelMultiEdit,
              onSave: (payload) =>
                  _saveCounterpartySelection(selectedRows, payload),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _CatalogTableList(
              emptyLabel: 'No hay contrapartes para mostrar.',
              contentWidth: _kCounterpartyContentW,
              rows: rows
                  .map((row) {
                    final rowKey = 'cp:${(row['id'] ?? '').toString()}';
                    if (_editingRowKey == rowKey) {
                      return _CounterpartyInlineEditRow(
                        row: row,
                        sites: _sites,
                        onCancel: _cancelInlineEdit,
                        onSave: (payload) =>
                            _saveCounterpartyInline(row, payload),
                      );
                    }
                    return _CatalogTableRow(
                      rowKey: rowKey,
                      selected: _currentSelectionKeys().contains(rowKey),
                      onTap: () =>
                          _handleRowSelection(rowKey, counterpartyRowKeys),
                      onPrimaryPointerDown: () =>
                          _beginDragSelection(rowKey, counterpartyRowKeys),
                      onDragEnter: () => _updateDragSelection(rowKey),
                      onPointerEnd: _endDragSelection,
                      onSecondarySelection: () => _handleRowSecondarySelection(
                        rowKey,
                        counterpartyRowKeys,
                      ),
                      onDoubleTap: () => _startInlineEdit(rowKey),
                      editableColumns: const {0, 1, 2, 3, 4, 5},
                      cells: [
                        _CatalogTableCell.text(
                          width: 250,
                          text: (row['name'] ?? '').toString(),
                          bold: true,
                        ),
                        _CatalogTableCell.text(
                          width: 120,
                          text: (row['kind'] ?? '').toString(),
                        ),
                        _CatalogTableCell.chip(
                          width: 140,
                          label: (row['group_code'] ?? '').toString(),
                          tone: const Color(0xFF8E3F2A),
                        ),
                        _CatalogTableCell.text(
                          width: 220,
                          text: _siteLabel(row['site_id']?.toString()) ?? '—',
                        ),
                        _CatalogTableCell.chip(
                          width: 110,
                          label: _isActive(row) ? 'ACTIVO' : 'INACTIVO',
                          tone: _isActive(row)
                              ? const Color(0xFF2F7D57)
                              : const Color(0xFF8F6D5A),
                        ),
                        _CatalogTableCell.text(
                          width: 260,
                          text: (row['notes'] ?? '').toString().trim().isEmpty
                              ? '—'
                              : (row['notes'] ?? '').toString(),
                        ),
                      ],
                      menuItems: _isMultiContextRow(rowKey)
                          ? [
                              if (!_multiEditMode)
                                _RowMenuAction(
                                  label: 'Editar selección',
                                  icon: Icons.edit_note_rounded,
                                  onTap: _startMultiEdit,
                                ),
                              if (_multiEditMode)
                                _RowMenuAction(
                                  label: 'Cancelar selección',
                                  icon: Icons.close_rounded,
                                  onTap: _cancelMultiEdit,
                                ),
                              _RowMenuAction(
                                label: 'Eliminar selección',
                                icon: Icons.delete_outline_rounded,
                                onTap: () => _deleteSelectedRows(
                                  _buildKeyboardRows(
                                    counterpartyRows: rows,
                                    generalRows: const [],
                                    commercialRows: const [],
                                    priceRows: const [],
                                  ),
                                ),
                              ),
                            ]
                          : [
                              _RowMenuAction(
                                label: 'Editar',
                                icon: Icons.edit_rounded,
                                onTap: () => _startInlineEdit(rowKey),
                              ),
                              _RowMenuAction(
                                label: _isActive(row)
                                    ? 'Desactivar'
                                    : 'Activar',
                                icon: _isActive(row)
                                    ? Icons.toggle_off_rounded
                                    : Icons.toggle_on_rounded,
                                onTap: () => _setActive(
                                  table: 'men_counterparties',
                                  id: (row['id'] ?? '').toString(),
                                  isActive: !_isActive(row),
                                  successLabel: _isActive(row)
                                      ? 'Contraparte desactivada'
                                      : 'Contraparte activada',
                                ),
                              ),
                              _RowMenuAction(
                                label: 'Eliminar',
                                icon: Icons.delete_outline_rounded,
                                onTap: () => _deleteRow(
                                  table: 'men_counterparties',
                                  id: (row['id'] ?? '').toString(),
                                  title: 'Eliminar contraparte',
                                  label: (row['name'] ?? '').toString(),
                                ),
                              ),
                            ],
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsTab(
    List<Map<String, dynamic>> generalRows,
    List<Map<String, dynamic>> commercialRows,
  ) {
    final materialRows = <Map<String, dynamic>>[
      ...generalRows.map((row) => {...row, '_level': 'GENERAL'}),
      ...commercialRows.map((row) => {...row, '_level': 'COMERCIAL'}),
    ];
    final materialRowKeys = materialRows
        .map(
          (row) =>
              '${row['_level'] == 'GENERAL' ? 'matg' : 'matc'}:${(row['id'] ?? '').toString()}',
        )
        .toList(growable: false);
    final selectedRows = materialRows
        .where(
          (row) => _currentSelectionKeys().contains(
            '${row['_level'] == 'GENERAL' ? 'matg' : 'matc'}:${(row['id'] ?? '').toString()}',
          ),
        )
        .toList(growable: false);

    return _CatalogTabSurface(
      child: Column(
        children: [
          _CatalogHeaderRow(
            columns: [
              _CatalogHeaderColumn(
                'NIVEL',
                110,
                active: _hasActiveFilter('material_level'),
                onFilter: () => _openColumnFilter(
                  columnId: 'material_level',
                  title: 'Filtrar nivel',
                  values: const ['GENERAL', 'COMERCIAL'],
                ),
              ),
              _CatalogHeaderColumn(
                'CODIGO',
                150,
                active: _hasActiveFilter('material_code'),
                onFilter: () => _openColumnFilter(
                  columnId: 'material_code',
                  title: 'Filtrar código',
                  values: [
                    ...generalRows.map((row) => (row['code'] ?? '').toString()),
                    ...commercialRows.map(
                      (row) => (row['code'] ?? '').toString(),
                    ),
                  ],
                ),
              ),
              _CatalogHeaderColumn(
                'MATERIAL',
                240,
                active: _hasActiveFilter('material_name'),
                onFilter: () => _openColumnFilter(
                  columnId: 'material_name',
                  title: 'Filtrar material',
                  values: [
                    ...generalRows.map((row) => (row['name'] ?? '').toString()),
                    ...commercialRows.map(
                      (row) => (row['name'] ?? '').toString(),
                    ),
                  ],
                ),
              ),
              _CatalogHeaderColumn(
                'FAMILIA',
                140,
                active: _hasActiveFilter('material_family'),
                onFilter: () => _openColumnFilter(
                  columnId: 'material_family',
                  title: 'Filtrar familia',
                  values: commercialRows
                      .map((row) => (row['family'] ?? '').toString())
                      .toList(),
                ),
              ),
              _CatalogHeaderColumn(
                'RELACION',
                220,
                active: _hasActiveFilter('material_relation'),
                onFilter: () => _openColumnFilter(
                  columnId: 'material_relation',
                  title: 'Filtrar relación',
                  values: [
                    'CATALOGO BASE',
                    ...commercialRows.map(
                      (row) =>
                          _generalMaterialLabel(
                            row['general_material_id']?.toString(),
                          ) ??
                          '',
                    ),
                  ],
                ),
              ),
              _CatalogHeaderColumn(
                'ESTADO',
                110,
                active: _hasActiveFilter('material_status'),
                onFilter: () => _openColumnFilter(
                  columnId: 'material_status',
                  title: 'Filtrar estado',
                  values: [
                    ...generalRows.map(
                      (row) => _isActive(row) ? 'ACTIVO' : 'INACTIVO',
                    ),
                    ...commercialRows.map(
                      (row) => _isActive(row) ? 'ACTIVO' : 'INACTIVO',
                    ),
                  ],
                ),
              ),
              _CatalogHeaderColumn('NOTAS', 220),
              _CatalogHeaderColumn('ACCIONES', _kCatalogActionsW),
            ],
          ),
          const SizedBox(height: 8),
          _CatalogInlineInsertRow(
            contentWidth: _kMaterialsContentW,
            actionChild: _CatalogInlineAddButton(
              loading: _insertingMaterial,
              onTap: _insertMaterialInline,
            ),
            children: [
              _CatalogInlineFieldCell(
                width: 110,
                child: _CatalogPickerButtonField<String>(
                  focusNode: _materialDraftLevelFocus,
                  label: 'Nivel',
                  displayValue: _materialDraftLevel,
                  dialogTitle: 'Seleccionar nivel',
                  initialValue: _materialDraftLevel,
                  options: const [
                    _MenudeoPickerOption(value: 'GENERAL', label: 'GENERAL'),
                    _MenudeoPickerOption(
                      value: 'COMERCIAL',
                      label: 'COMERCIAL',
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _materialDraftLevel = value;
                      if (value == 'GENERAL') {
                        _materialDraftGeneralMaterialId = null;
                      }
                    });
                  },
                  onMoveNext: () => _materialDraftNameFocus.requestFocus(),
                  onMoveDown: () => _focusFirstVisibleRow(materialRowKeys),
                  onSelected: () => _materialDraftNameFocus.requestFocus(),
                ),
              ),
              _CatalogInlineFieldCell(
                width: 150,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _materialCodeFromName(_materialDraftNameC.text),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              _CatalogInlineFieldCell(
                width: 240,
                child: Focus(
                  onKeyEvent: (_, event) => _handleInsertTextNavigation(
                    event: event,
                    controller: _materialDraftNameC,
                    previous: _materialDraftLevelFocus,
                    next: _materialDraftLevel == 'GENERAL'
                        ? _materialDraftNotesFocus
                        : _materialDraftFamilyFocus,
                    onDown: () => _focusFirstVisibleRow(materialRowKeys),
                  ),
                  child: TextField(
                    controller: _materialDraftNameC,
                    focusNode: _materialDraftNameFocus,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _catalogInlineFieldDecoration(
                      context,
                      'Material',
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (_materialDraftLevel == 'GENERAL') {
                        _materialDraftNotesFocus.requestFocus();
                      } else {
                        _materialDraftFamilyFocus.requestFocus();
                      }
                    },
                  ),
                ),
              ),
              _CatalogInlineFieldCell(
                width: 140,
                child: _materialDraftLevel == 'GENERAL'
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '—',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      )
                    : _CatalogPickerButtonField<String>(
                        focusNode: _materialDraftFamilyFocus,
                        label: 'Familia',
                        displayValue: _materialDraftFamily,
                        dialogTitle: 'Seleccionar familia',
                        initialValue: _materialDraftFamily,
                        options: const [
                          _MenudeoPickerOption(
                            value: 'cardboard',
                            label: 'cardboard',
                          ),
                          _MenudeoPickerOption(value: 'scrap', label: 'scrap'),
                          _MenudeoPickerOption(value: 'metal', label: 'metal'),
                          _MenudeoPickerOption(value: 'paper', label: 'paper'),
                          _MenudeoPickerOption(
                            value: 'plastic',
                            label: 'plastic',
                          ),
                          _MenudeoPickerOption(value: 'wood', label: 'wood'),
                          _MenudeoPickerOption(value: 'other', label: 'other'),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _materialDraftFamily = value);
                        },
                        onMovePrev: () =>
                            _materialDraftNameFocus.requestFocus(),
                        onMoveNext: () =>
                            _materialDraftRelationFocus.requestFocus(),
                        onMoveDown: () =>
                            _focusFirstVisibleRow(materialRowKeys),
                        onSelected: () =>
                            _materialDraftRelationFocus.requestFocus(),
                      ),
              ),
              _CatalogInlineFieldCell(
                width: 220,
                child: _materialDraftLevel == 'GENERAL'
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Catalogo base',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      )
                    : _CatalogPickerButtonField<String>(
                        focusNode: _materialDraftRelationFocus,
                        label: 'Relacion',
                        displayValue:
                            _generalMaterialLabel(
                              _materialDraftGeneralMaterialId,
                            ) ??
                            '',
                        dialogTitle: 'Seleccionar material general',
                        initialValue: _materialDraftGeneralMaterialId,
                        options: _generalMaterials
                            .where(_isActive)
                            .map(
                              (row) => _MenudeoPickerOption<String>(
                                value: (row['id'] ?? '').toString(),
                                label: (row['name'] ?? '').toString(),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(
                            () => _materialDraftGeneralMaterialId = value,
                          );
                        },
                        onMovePrev: () =>
                            _materialDraftFamilyFocus.requestFocus(),
                        onMoveNext: () =>
                            _materialDraftNotesFocus.requestFocus(),
                        onMoveDown: () =>
                            _focusFirstVisibleRow(materialRowKeys),
                        onSelected: () =>
                            _materialDraftNotesFocus.requestFocus(),
                      ),
              ),
              const _CatalogInlineFieldCell(
                width: 110,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ACTIVO',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              _CatalogInlineFieldCell(
                width: 220,
                child: Focus(
                  onKeyEvent: (_, event) => _handleInsertTextNavigation(
                    event: event,
                    controller: _materialDraftNotesC,
                    previous: _materialDraftLevel == 'GENERAL'
                        ? _materialDraftNameFocus
                        : _materialDraftRelationFocus,
                    onDown: () => _focusFirstVisibleRow(materialRowKeys),
                  ),
                  child: TextField(
                    controller: _materialDraftNotesC,
                    focusNode: _materialDraftNotesFocus,
                    decoration: _catalogInlineFieldDecoration(context, 'Notas'),
                    onSubmitted: (_) => _insertMaterialInline(),
                  ),
                ),
              ),
            ],
          ),
          if (_multiEditMode && selectedRows.length > 1) ...[
            const SizedBox(height: 8),
            _MaterialsSelectionEditRow(
              selectedCount: selectedRows.length,
              onCancel: _cancelMultiEdit,
              onSave: (payload) =>
                  _saveMaterialsSelection(selectedRows, payload),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _CatalogTableList(
              emptyLabel: 'No hay materiales para mostrar.',
              contentWidth: _kMaterialsContentW,
              rows: materialRows
                  .map((row) {
                    final rowKey =
                        '${row['_level'] == 'GENERAL' ? 'matg' : 'matc'}:${(row['id'] ?? '').toString()}';
                    if (_editingRowKey == rowKey) {
                      if (row['_level'] == 'GENERAL') {
                        return _GeneralMaterialInlineEditRow(
                          row: row,
                          onCancel: _cancelInlineEdit,
                          onSave: (payload) =>
                              _saveGeneralMaterialInline(row, payload),
                        );
                      }
                      return _CommercialMaterialInlineEditRow(
                        row: row,
                        generalMaterials: _generalMaterials,
                        onCancel: _cancelInlineEdit,
                        onSave: (payload) =>
                            _saveCommercialMaterialInline(row, payload),
                      );
                    }
                    return _CatalogTableRow(
                      rowKey: rowKey,
                      selected: _currentSelectionKeys().contains(rowKey),
                      onTap: () => _handleRowSelection(rowKey, materialRowKeys),
                      onPrimaryPointerDown: () =>
                          _beginDragSelection(rowKey, materialRowKeys),
                      onDragEnter: () => _updateDragSelection(rowKey),
                      onPointerEnd: _endDragSelection,
                      onSecondarySelection: () =>
                          _handleRowSecondarySelection(rowKey, materialRowKeys),
                      onDoubleTap: () => _startInlineEdit(rowKey),
                      editableColumns: const {2, 3, 4, 5, 6},
                      cells: [
                        _CatalogTableCell.chip(
                          width: 110,
                          label: (row['_level'] ?? '').toString(),
                          tone: row['_level'] == 'GENERAL'
                              ? const Color(0xFF8E3F2A)
                              : const Color(0xFFE89A5B),
                        ),
                        _CatalogTableCell.text(
                          width: 150,
                          text: (row['code'] ?? '').toString(),
                        ),
                        _CatalogTableCell.text(
                          width: 240,
                          text: (row['name'] ?? '').toString(),
                          bold: true,
                        ),
                        _CatalogTableCell.text(
                          width: 140,
                          text: row['_level'] == 'GENERAL'
                              ? '—'
                              : (row['family'] ?? '').toString(),
                        ),
                        _CatalogTableCell.text(
                          width: 220,
                          text: row['_level'] == 'GENERAL'
                              ? 'Catalogo base'
                              : (_generalMaterialLabel(
                                      row['general_material_id']?.toString(),
                                    ) ??
                                    '—'),
                        ),
                        _CatalogTableCell.chip(
                          width: 110,
                          label: _isActive(row) ? 'ACTIVO' : 'INACTIVO',
                          tone: _isActive(row)
                              ? const Color(0xFF2F7D57)
                              : const Color(0xFF8F6D5A),
                        ),
                        _CatalogTableCell.text(
                          width: 220,
                          text: (row['notes'] ?? '').toString().trim().isEmpty
                              ? '—'
                              : (row['notes'] ?? '').toString(),
                        ),
                      ],
                      menuItems: _isMultiContextRow(rowKey)
                          ? [
                              if (!_multiEditMode)
                                _RowMenuAction(
                                  label: 'Editar selección',
                                  icon: Icons.edit_note_rounded,
                                  onTap: _startMultiEdit,
                                ),
                              if (_multiEditMode)
                                _RowMenuAction(
                                  label: 'Cancelar selección',
                                  icon: Icons.close_rounded,
                                  onTap: _cancelMultiEdit,
                                ),
                              _RowMenuAction(
                                label: 'Eliminar selección',
                                icon: Icons.delete_outline_rounded,
                                onTap: () => _deleteSelectedRows(
                                  _buildKeyboardRows(
                                    counterpartyRows: const [],
                                    generalRows: generalRows,
                                    commercialRows: commercialRows,
                                    priceRows: const [],
                                  ),
                                ),
                              ),
                            ]
                          : [
                              _RowMenuAction(
                                label: 'Editar',
                                icon: Icons.edit_rounded,
                                onTap: () => _startInlineEdit(rowKey),
                              ),
                              _RowMenuAction(
                                label: _isActive(row)
                                    ? 'Desactivar'
                                    : 'Activar',
                                icon: _isActive(row)
                                    ? Icons.toggle_off_rounded
                                    : Icons.toggle_on_rounded,
                                onTap: () => _setActive(
                                  table: row['_level'] == 'GENERAL'
                                      ? 'material_general_catalog_v2'
                                      : 'material_commercial_catalog_v2',
                                  id: (row['id'] ?? '').toString(),
                                  isActive: !_isActive(row),
                                  successLabel: row['_level'] == 'GENERAL'
                                      ? (_isActive(row)
                                            ? 'Material general desactivado'
                                            : 'Material general activado')
                                      : (_isActive(row)
                                            ? 'Material comercial desactivado'
                                            : 'Material comercial activado'),
                                ),
                              ),
                              _RowMenuAction(
                                label: 'Eliminar',
                                icon: Icons.delete_outline_rounded,
                                onTap: () => _deleteRow(
                                  table: row['_level'] == 'GENERAL'
                                      ? 'material_general_catalog_v2'
                                      : 'material_commercial_catalog_v2',
                                  id: (row['id'] ?? '').toString(),
                                  title: row['_level'] == 'GENERAL'
                                      ? 'Eliminar material general'
                                      : 'Eliminar material comercial',
                                  label: (row['name'] ?? '').toString(),
                                ),
                              ),
                            ],
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricesTab(List<Map<String, dynamic>> rows) {
    final priceRowKeys = rows
        .map((row) => 'price:${(row['price_id'] ?? '').toString()}')
        .toList(growable: false);
    final selectedRows = rows
        .where(
          (row) => _currentSelectionKeys().contains(
            'price:${(row['price_id'] ?? '').toString()}',
          ),
        )
        .toList(growable: false);
    return _CatalogTabSurface(
      child: Column(
        children: [
          _CatalogHeaderRow(
            columns: [
              _CatalogHeaderColumn(
                'CONTRAPARTE',
                240,
                active: _hasActiveFilter('price_counterparty'),
                onFilter: () => _openColumnFilter(
                  columnId: 'price_counterparty',
                  title: 'Filtrar contraparte',
                  values: rows
                      .map((row) => (row['counterparty_name'] ?? '').toString())
                      .toList(),
                ),
              ),
              _CatalogHeaderColumn(
                'GRUPO',
                130,
                active: _hasActiveFilter('price_group'),
                onFilter: () => _openColumnFilter(
                  columnId: 'price_group',
                  title: 'Filtrar grupo',
                  values: rows
                      .map((row) => (row['group_code'] ?? '').toString())
                      .toList(),
                ),
              ),
              _CatalogHeaderColumn(
                'MATERIAL',
                240,
                active: _hasActiveFilter('price_material'),
                onFilter: () => _openColumnFilter(
                  columnId: 'price_material',
                  title: 'Filtrar material',
                  values: rows
                      .map(
                        (row) =>
                            (row['material_label_snapshot'] ?? '').toString(),
                      )
                      .toList(),
                ),
              ),
              _CatalogHeaderColumn(
                'PRECIO',
                120,
                active: _hasActiveFilter('price_amount'),
                onFilter: () => _openColumnFilter(
                  columnId: 'price_amount',
                  title: 'Filtrar precio',
                  values: rows
                      .map((row) => (row['final_price'] ?? '').toString())
                      .toList(),
                ),
              ),
              _CatalogHeaderColumn(
                'ESTADO',
                110,
                active: _hasActiveFilter('price_status'),
                onFilter: () => _openColumnFilter(
                  columnId: 'price_status',
                  title: 'Filtrar estado',
                  values: rows
                      .map(
                        (row) => _isActive(row, key: 'price_active')
                            ? 'ACTIVO'
                            : 'INACTIVO',
                      )
                      .toList(),
                ),
              ),
              _CatalogHeaderColumn('NOTAS', 260),
              _CatalogHeaderColumn('ACCIONES', _kCatalogActionsW),
            ],
          ),
          const SizedBox(height: 8),
          _CatalogInlineInsertRow(
            contentWidth: _kPricesContentW,
            actionChild: _CatalogInlineAddButton(
              loading: _insertingPrice,
              onTap: _insertPriceInline,
            ),
            children: [
              _CatalogInlineFieldCell(
                width: 240,
                child: _CatalogPickerButtonField<String>(
                  focusNode: _priceDraftCounterpartyFocus,
                  label: 'Contraparte',
                  displayValue:
                      _counterparties
                          .firstWhere(
                            (row) =>
                                (row['id'] ?? '').toString() ==
                                _priceDraftCounterpartyId,
                            orElse: () => const {},
                          )['name']
                          ?.toString() ??
                      '',
                  dialogTitle: 'Seleccionar contraparte',
                  initialValue: _priceDraftCounterpartyId,
                  options: _counterparties
                      .where(_isActive)
                      .map(
                        (row) => _MenudeoPickerOption<String>(
                          value: (row['id'] ?? '').toString(),
                          label: (row['name'] ?? '').toString(),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _priceDraftCounterpartyId = value);
                  },
                  onMoveNext: () => _priceDraftMaterialFocus.requestFocus(),
                  onMoveDown: () => _focusFirstVisibleRow(priceRowKeys),
                  onSelected: () => _priceDraftMaterialFocus.requestFocus(),
                ),
              ),
              const _CatalogInlineFieldCell(
                width: 130,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'AUTO',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              _CatalogInlineFieldCell(
                width: 240,
                child: _CatalogPickerButtonField<String?>(
                  focusNode: _priceDraftMaterialFocus,
                  label: 'Material comercial',
                  displayValue:
                      _commercialMaterialLabel(
                        _priceDraftCommercialMaterialId,
                      ) ??
                      '',
                  dialogTitle: 'Seleccionar material comercial',
                  initialValue: _priceDraftCommercialMaterialId,
                  allowClear: true,
                  options: _commercialMaterials
                      .where(_isActive)
                      .map(
                        (row) => _MenudeoPickerOption<String?>(
                          value: (row['id'] ?? '').toString(),
                          label: (row['name'] ?? '').toString(),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setState(() => _priceDraftCommercialMaterialId = value),
                  onMovePrev: () => _priceDraftCounterpartyFocus.requestFocus(),
                  onMoveNext: () => _priceDraftAmountFocus.requestFocus(),
                  onMoveDown: () => _focusFirstVisibleRow(priceRowKeys),
                  onSelected: () => _priceDraftAmountFocus.requestFocus(),
                ),
              ),
              _CatalogInlineFieldCell(
                width: 120,
                child: Focus(
                  onKeyEvent: (_, event) => _handleInsertTextNavigation(
                    event: event,
                    controller: _priceDraftAmountC,
                    previous: _priceDraftMaterialFocus,
                    next: _priceDraftNotesFocus,
                    onDown: () => _focusFirstVisibleRow(priceRowKeys),
                  ),
                  child: TextField(
                    controller: _priceDraftAmountC,
                    focusNode: _priceDraftAmountFocus,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: _catalogInlineFieldDecoration(
                      context,
                      'Precio',
                    ),
                    onSubmitted: (_) => _priceDraftNotesFocus.requestFocus(),
                  ),
                ),
              ),
              const _CatalogInlineFieldCell(
                width: 110,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ACTIVO',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              _CatalogInlineFieldCell(
                width: 260,
                child: Focus(
                  onKeyEvent: (_, event) => _handleInsertTextNavigation(
                    event: event,
                    controller: _priceDraftNotesC,
                    previous: _priceDraftAmountFocus,
                    onDown: () => _focusFirstVisibleRow(priceRowKeys),
                  ),
                  child: TextField(
                    controller: _priceDraftNotesC,
                    focusNode: _priceDraftNotesFocus,
                    decoration: _catalogInlineFieldDecoration(context, 'Notas'),
                    onSubmitted: (_) => _insertPriceInline(),
                  ),
                ),
              ),
            ],
          ),
          if (_multiEditMode && selectedRows.length > 1) ...[
            const SizedBox(height: 8),
            _PricesSelectionEditRow(
              selectedCount: selectedRows.length,
              onCancel: _cancelMultiEdit,
              onSave: (payload) => _savePricesSelection(selectedRows, payload),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _CatalogTableList(
              emptyLabel: 'No hay precios para mostrar.',
              contentWidth: _kPricesContentW,
              rows: rows
                  .map((row) {
                    final rowKey =
                        'price:${(row['price_id'] ?? '').toString()}';
                    if (_editingRowKey == rowKey) {
                      return _PriceInlineEditRow(
                        row: row,
                        counterparties: _counterparties,
                        generalMaterials: _generalMaterials,
                        commercialMaterials: _commercialMaterials,
                        onCancel: _cancelInlineEdit,
                        onSave: (payload) => _savePriceInline(row, payload),
                      );
                    }
                    return _CatalogTableRow(
                      rowKey: rowKey,
                      selected: _currentSelectionKeys().contains(rowKey),
                      onTap: () => _handleRowSelection(rowKey, priceRowKeys),
                      onPrimaryPointerDown: () =>
                          _beginDragSelection(rowKey, priceRowKeys),
                      onDragEnter: () => _updateDragSelection(rowKey),
                      onPointerEnd: _endDragSelection,
                      onSecondarySelection: () =>
                          _handleRowSecondarySelection(rowKey, priceRowKeys),
                      onDoubleTap: () => _startInlineEdit(rowKey),
                      editableColumns: const {0, 2, 3, 4, 5},
                      cells: [
                        _CatalogTableCell.text(
                          width: 240,
                          text: (row['counterparty_name'] ?? '').toString(),
                          bold: true,
                        ),
                        _CatalogTableCell.chip(
                          width: 130,
                          label: (row['group_code'] ?? '').toString(),
                          tone: const Color(0xFFB65C2A),
                        ),
                        _CatalogTableCell.text(
                          width: 240,
                          text: (row['material_label_snapshot'] ?? '')
                              .toString(),
                        ),
                        _CatalogTableCell.text(
                          width: 120,
                          text: '\$${(row['final_price'] ?? '').toString()}',
                          bold: true,
                        ),
                        _CatalogTableCell.chip(
                          width: 110,
                          label: _isActive(row, key: 'price_active')
                              ? 'ACTIVO'
                              : 'INACTIVO',
                          tone: _isActive(row, key: 'price_active')
                              ? const Color(0xFF2F7D57)
                              : const Color(0xFF8F6D5A),
                        ),
                        _CatalogTableCell.text(
                          width: 260,
                          text: (row['notes'] ?? '').toString().trim().isEmpty
                              ? '—'
                              : (row['notes'] ?? '').toString(),
                        ),
                      ],
                      menuItems: [
                        _RowMenuAction(
                          label: 'Editar',
                          icon: Icons.edit_rounded,
                          onTap: () => _startInlineEdit(rowKey),
                        ),
                        _RowMenuAction(
                          label: _isActive(row, key: 'price_active')
                              ? 'Desactivar'
                              : 'Activar',
                          icon: _isActive(row, key: 'price_active')
                              ? Icons.toggle_off_rounded
                              : Icons.toggle_on_rounded,
                          onTap: () => _setActive(
                            table: 'men_counterparty_material_prices',
                            id: (row['price_id'] ?? '').toString(),
                            isActive: !_isActive(row, key: 'price_active'),
                            successLabel: _isActive(row, key: 'price_active')
                                ? 'Precio desactivado'
                                : 'Precio activado',
                          ),
                        ),
                        _RowMenuAction(
                          label: 'Eliminar',
                          icon: Icons.delete_outline_rounded,
                          onTap: () => _deleteRow(
                            table: 'men_counterparty_material_prices',
                            id: (row['price_id'] ?? '').toString(),
                            title: 'Eliminar precio',
                            label:
                                '${(row['counterparty_name'] ?? '').toString()} · ${(row['material_label_snapshot'] ?? '').toString()}',
                          ),
                        ),
                      ],
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _catalogInlineFieldDecoration(
  BuildContext context,
  String hintText,
) {
  return contractGlassFieldDecoration(context, hintText: hintText).copyWith(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

class _CatalogInlineInsertRow extends StatelessWidget {
  final double contentWidth;
  final List<Widget> children;
  final Widget actionChild;
  final bool editing;
  final String? statusLabel;

  const _CatalogInlineInsertRow({
    required this.contentWidth,
    required this.children,
    required this.actionChild,
    this.editing = false,
    this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: editing
            ? tokens.badgeBackground.withValues(alpha: 0.68)
            : Colors.white.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: editing
              ? tokens.primaryStrong.withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.28),
          width: editing ? 1.4 : 1,
        ),
        boxShadow: editing
            ? [
                BoxShadow(
                  color: tokens.glow.withValues(alpha: 0.14),
                  blurRadius: 20,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (editing && statusLabel != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: tokens.primaryStrong,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusLabel!,
                      style: TextStyle(
                        color: tokens.primaryStrong,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  child: ContractGridScaledRow(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...children,
                        AnchoredActionSlot(
                          width: _kCatalogActionsW,
                          trailingWidth: _kCatalogActionsW,
                          leading: const SizedBox.shrink(),
                          trailing: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: actionChild,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogInlineFieldCell extends StatelessWidget {
  final double width;
  final Widget child;

  const _CatalogInlineFieldCell({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(padding: const EdgeInsets.only(right: 10), child: child),
    );
  }
}

class _CatalogInlineAddButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _CatalogInlineAddButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: loading
              ? Colors.white.withValues(alpha: 0.35)
              : const Color(0xFF19C37D).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.52)),
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add, size: 18, color: Colors.white),
      ),
    );
  }
}

class _CatalogInlineActionButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final Color color;

  const _CatalogInlineActionButton({
    required this.onTap,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: onTap == null ? 0.28 : 0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.52)),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _CounterpartyInlineEditRow extends StatefulWidget {
  final Map<String, dynamic> row;
  final List<Map<String, dynamic>> sites;
  final VoidCallback onCancel;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _CounterpartyInlineEditRow({
    required this.row,
    required this.sites,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_CounterpartyInlineEditRow> createState() =>
      _CounterpartyInlineEditRowState();
}

class _CounterpartyInlineEditRowState
    extends State<_CounterpartyInlineEditRow> {
  late final TextEditingController _nameC;
  late final TextEditingController _groupC;
  late final TextEditingController _notesC;
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _kindFocus = FocusNode();
  final FocusNode _groupFocus = FocusNode();
  final FocusNode _siteFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();
  late String _kind;
  String? _siteId;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: (widget.row['name'] ?? '').toString());
    _groupC = TextEditingController(
      text: (widget.row['group_code'] ?? '').toString(),
    );
    _notesC = TextEditingController(
      text: (widget.row['notes'] ?? '').toString(),
    );
    _kind = (widget.row['kind'] ?? 'supplier').toString();
    _siteId = widget.row['site_id']?.toString();
    _isActive = (widget.row['is_active'] ?? true) == true;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _groupC.dispose();
    _notesC.dispose();
    _nameFocus.dispose();
    _kindFocus.dispose();
    _groupFocus.dispose();
    _siteFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSave({
      'name': _normalizeName(_nameC.text),
      'group_code': _normalizeName(_groupC.text),
      'kind': _kind,
      'site_id': _siteId,
      'notes': _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
      'is_active': _isActive,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final pressedSave =
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed) &&
            event.logicalKey == LogicalKeyboardKey.keyS;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onCancel();
          return KeyEventResult.handled;
        }
        if (pressedSave) {
          _submit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: _CatalogInlineInsertRow(
        contentWidth: _kCounterpartyContentW,
        editing: true,
        statusLabel: 'EDITANDO CONTRAPARTE',
        actionChild: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _CatalogInlineActionButton(
              onTap: widget.onCancel,
              icon: Icons.close_rounded,
              color: const Color(0xFF8F6D5A),
            ),
            const SizedBox(width: 8),
            _CatalogInlineActionButton(
              onTap: _submit,
              icon: Icons.check_rounded,
              color: const Color(0xFF19C37D),
            ),
          ],
        ),
        children: [
          _CatalogInlineFieldCell(
            width: 250,
            child: TextField(
              controller: _nameC,
              focusNode: _nameFocus,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: _catalogInlineFieldDecoration(context, 'Contraparte'),
              onSubmitted: (_) => _kindFocus.requestFocus(),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 120,
            child: _CatalogPickerButtonField<String>(
              focusNode: _kindFocus,
              label: 'Tipo',
              displayValue: switch (_kind) {
                'supplier' => 'Proveedor',
                'customer' => 'Cliente',
                'both' => 'Ambos',
                _ => _kind,
              },
              dialogTitle: 'Seleccionar tipo',
              initialValue: _kind,
              options: const [
                _MenudeoPickerOption(value: 'supplier', label: 'Proveedor'),
                _MenudeoPickerOption(value: 'customer', label: 'Cliente'),
                _MenudeoPickerOption(value: 'both', label: 'Ambos'),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _kind = value);
              },
              onSelected: () => _groupFocus.requestFocus(),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 140,
            child: TextField(
              controller: _groupC,
              focusNode: _groupFocus,
              textCapitalization: TextCapitalization.characters,
              decoration: _catalogInlineFieldDecoration(context, 'Grupo'),
              onSubmitted: (_) => _notesFocus.requestFocus(),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 220,
            child: _CatalogPickerButtonField<String?>(
              label: 'Empresa',
              displayValue:
                  widget.sites
                      .firstWhere(
                        (row) => (row['id'] ?? '').toString() == _siteId,
                        orElse: () => const {},
                      )['name']
                      ?.toString() ??
                  '',
              dialogTitle: 'Seleccionar empresa',
              initialValue: _siteId,
              focusNode: _siteFocus,
              allowClear: true,
              options: widget.sites
                  .map(
                    (row) => _MenudeoPickerOption<String?>(
                      value: (row['id'] ?? '').toString(),
                      label: (row['name'] ?? '').toString(),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _siteId = value),
              onSelected: () => _notesFocus.requestFocus(),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: _isActive ? 'Activo' : 'Inactivo',
                child: Switch(
                  value: _isActive,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 260,
            child: TextField(
              controller: _notesC,
              focusNode: _notesFocus,
              decoration: _catalogInlineFieldDecoration(context, 'Notas'),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceInlineEditRow extends StatefulWidget {
  final Map<String, dynamic> row;
  final List<Map<String, dynamic>> counterparties;
  final List<Map<String, dynamic>> generalMaterials;
  final List<Map<String, dynamic>> commercialMaterials;
  final VoidCallback onCancel;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _PriceInlineEditRow({
    required this.row,
    required this.counterparties,
    required this.generalMaterials,
    required this.commercialMaterials,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_PriceInlineEditRow> createState() => _PriceInlineEditRowState();
}

class _PriceInlineEditRowState extends State<_PriceInlineEditRow> {
  late final TextEditingController _amountC;
  late final TextEditingController _notesC;
  final FocusNode _counterpartyFocus = FocusNode();
  final FocusNode _materialFocus = FocusNode();
  final FocusNode _amountFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();
  String? _counterpartyId;
  String? _generalMaterialId;
  String? _commercialMaterialId;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _amountC = TextEditingController(
      text: (widget.row['final_price'] ?? '').toString(),
    );
    _notesC = TextEditingController(
      text: (widget.row['notes'] ?? '').toString(),
    );
    _counterpartyId = widget.row['counterparty_id']?.toString();
    _generalMaterialId = widget.row['general_material_id']?.toString();
    _commercialMaterialId = widget.row['commercial_material_id']?.toString();
    _isActive = (widget.row['price_active'] ?? true) == true;
  }

  @override
  void dispose() {
    _amountC.dispose();
    _notesC.dispose();
    _counterpartyFocus.dispose();
    _materialFocus.dispose();
    _amountFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  String _materialLabel() {
    final commercial = widget.commercialMaterials.firstWhere(
      (row) => (row['id'] ?? '').toString() == _commercialMaterialId,
      orElse: () => const {},
    );
    final commercialName = (commercial['name'] ?? '').toString();
    if (commercialName.isNotEmpty) return commercialName;

    final general = widget.generalMaterials.firstWhere(
      (row) => (row['id'] ?? '').toString() == _generalMaterialId,
      orElse: () => const {},
    );
    return (general['name'] ?? '').toString();
  }

  String _groupLabel() {
    final counterparty = widget.counterparties.firstWhere(
      (row) => (row['id'] ?? '').toString() == _counterpartyId,
      orElse: () => const {},
    );
    final label = (counterparty['group_code'] ?? '').toString();
    return label.isEmpty ? 'AUTO' : label;
  }

  void _submit() {
    final parsed = double.tryParse(_amountC.text.trim());
    widget.onSave({
      'counterparty_id': _counterpartyId,
      'general_material_id': _generalMaterialId,
      'commercial_material_id': _commercialMaterialId,
      'material_label_snapshot': _materialLabel(),
      'final_price': parsed,
      'notes': _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
      'is_active': _isActive,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final pressedSave =
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed) &&
            event.logicalKey == LogicalKeyboardKey.keyS;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onCancel();
          return KeyEventResult.handled;
        }
        if (pressedSave) {
          _submit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: _CatalogInlineInsertRow(
        contentWidth: _kPricesContentW,
        editing: true,
        statusLabel: 'EDITANDO PRECIO',
        actionChild: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _CatalogInlineActionButton(
              onTap: widget.onCancel,
              icon: Icons.close_rounded,
              color: const Color(0xFF8F6D5A),
            ),
            const SizedBox(width: 8),
            _CatalogInlineActionButton(
              onTap: _submit,
              icon: Icons.check_rounded,
              color: const Color(0xFF19C37D),
            ),
          ],
        ),
        children: [
          _CatalogInlineFieldCell(
            width: 240,
            child: _CatalogPickerButtonField<String>(
              focusNode: _counterpartyFocus,
              label: 'Contraparte',
              displayValue:
                  widget.counterparties
                      .firstWhere(
                        (row) =>
                            (row['id'] ?? '').toString() == _counterpartyId,
                        orElse: () => const {},
                      )['name']
                      ?.toString() ??
                  '',
              dialogTitle: 'Seleccionar contraparte',
              initialValue: _counterpartyId,
              options: widget.counterparties
                  .where((row) => (row['is_active'] ?? true) == true)
                  .map(
                    (row) => _MenudeoPickerOption<String>(
                      value: (row['id'] ?? '').toString(),
                      label: (row['name'] ?? '').toString(),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _counterpartyId = value);
              },
              onSelected: () => _materialFocus.requestFocus(),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 130,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _groupLabel(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 240,
            child: _CatalogPickerButtonField<String?>(
              focusNode: _materialFocus,
              label: 'Material comercial',
              displayValue: _materialLabel(),
              dialogTitle: 'Seleccionar material comercial',
              initialValue: _commercialMaterialId,
              allowClear: true,
              options: widget.commercialMaterials
                  .where((row) => (row['is_active'] ?? true) == true)
                  .map(
                    (row) => _MenudeoPickerOption<String?>(
                      value: (row['id'] ?? '').toString(),
                      label: (row['name'] ?? '').toString(),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) =>
                  setState(() => _commercialMaterialId = value),
              onSelected: () => _amountFocus.requestFocus(),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 120,
            child: TextField(
              controller: _amountC,
              focusNode: _amountFocus,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: _catalogInlineFieldDecoration(context, 'Precio'),
              onSubmitted: (_) => _notesFocus.requestFocus(),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: _isActive ? 'Activo' : 'Inactivo',
                child: Switch(
                  value: _isActive,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 260,
            child: TextField(
              controller: _notesC,
              focusNode: _notesFocus,
              decoration: _catalogInlineFieldDecoration(context, 'Notas'),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneralMaterialInlineEditRow extends StatefulWidget {
  final Map<String, dynamic> row;
  final VoidCallback onCancel;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _GeneralMaterialInlineEditRow({
    required this.row,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_GeneralMaterialInlineEditRow> createState() =>
      _GeneralMaterialInlineEditRowState();
}

class _GeneralMaterialInlineEditRowState
    extends State<_GeneralMaterialInlineEditRow> {
  late final TextEditingController _nameC;
  late final TextEditingController _notesC;
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: (widget.row['name'] ?? '').toString());
    _notesC = TextEditingController(
      text: (widget.row['notes'] ?? '').toString(),
    );
    _isActive = (widget.row['is_active'] ?? true) == true;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _notesC.dispose();
    _nameFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSave({
      'name': _normalizeName(_nameC.text),
      'notes': _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
      'is_active': _isActive,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final pressedSave =
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed) &&
            event.logicalKey == LogicalKeyboardKey.keyS;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onCancel();
          return KeyEventResult.handled;
        }
        if (pressedSave) {
          _submit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: _CatalogInlineInsertRow(
        contentWidth: _kMaterialsContentW,
        editing: true,
        statusLabel: 'EDITANDO MATERIAL GENERAL',
        actionChild: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _CatalogInlineActionButton(
              onTap: widget.onCancel,
              icon: Icons.close_rounded,
              color: const Color(0xFF8F6D5A),
            ),
            const SizedBox(width: 8),
            _CatalogInlineActionButton(
              onTap: _submit,
              icon: Icons.check_rounded,
              color: const Color(0xFF19C37D),
            ),
          ],
        ),
        children: [
          _CatalogInlineFieldCell(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _RowChip(label: 'GENERAL', tone: const Color(0xFF8E3F2A)),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 150,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _materialCodeFromName(_nameC.text),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 240,
            child: TextField(
              controller: _nameC,
              focusNode: _nameFocus,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: _catalogInlineFieldDecoration(context, 'Material'),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _notesFocus.requestFocus(),
            ),
          ),
          const _CatalogInlineFieldCell(
            width: 140,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('—', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const _CatalogInlineFieldCell(
            width: 220,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Catalogo base',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: _isActive ? 'Activo' : 'Inactivo',
                child: Switch(
                  value: _isActive,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 220,
            child: TextField(
              controller: _notesC,
              focusNode: _notesFocus,
              decoration: _catalogInlineFieldDecoration(context, 'Notas'),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommercialMaterialInlineEditRow extends StatefulWidget {
  final Map<String, dynamic> row;
  final List<Map<String, dynamic>> generalMaterials;
  final VoidCallback onCancel;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _CommercialMaterialInlineEditRow({
    required this.row,
    required this.generalMaterials,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_CommercialMaterialInlineEditRow> createState() =>
      _CommercialMaterialInlineEditRowState();
}

class _CommercialMaterialInlineEditRowState
    extends State<_CommercialMaterialInlineEditRow> {
  static const _familyOptions = <String>[
    'cardboard',
    'scrap',
    'metal',
    'paper',
    'plastic',
    'wood',
    'other',
  ];

  late final TextEditingController _nameC;
  late final TextEditingController _notesC;
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _familyFocus = FocusNode();
  final FocusNode _generalFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();
  late String _family;
  String? _generalMaterialId;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: (widget.row['name'] ?? '').toString());
    _notesC = TextEditingController(
      text: (widget.row['notes'] ?? '').toString(),
    );
    _family = (widget.row['family'] ?? 'other').toString();
    _generalMaterialId = widget.row['general_material_id']?.toString();
    _isActive = (widget.row['is_active'] ?? true) == true;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _notesC.dispose();
    _nameFocus.dispose();
    _familyFocus.dispose();
    _generalFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSave({
      'name': _normalizeName(_nameC.text),
      'family': _family,
      'general_material_id': _generalMaterialId,
      'notes': _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
      'is_active': _isActive,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final pressedSave =
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed) &&
            event.logicalKey == LogicalKeyboardKey.keyS;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onCancel();
          return KeyEventResult.handled;
        }
        if (pressedSave) {
          _submit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: _CatalogInlineInsertRow(
        contentWidth: _kMaterialsContentW,
        editing: true,
        statusLabel: 'EDITANDO MATERIAL COMERCIAL',
        actionChild: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _CatalogInlineActionButton(
              onTap: widget.onCancel,
              icon: Icons.close_rounded,
              color: const Color(0xFF8F6D5A),
            ),
            const SizedBox(width: 8),
            _CatalogInlineActionButton(
              onTap: _submit,
              icon: Icons.check_rounded,
              color: const Color(0xFF19C37D),
            ),
          ],
        ),
        children: [
          _CatalogInlineFieldCell(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _RowChip(
                label: 'COMERCIAL',
                tone: const Color(0xFFE89A5B),
              ),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 150,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _materialCodeFromName(_nameC.text),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 240,
            child: TextField(
              controller: _nameC,
              focusNode: _nameFocus,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: _catalogInlineFieldDecoration(context, 'Material'),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _familyFocus.requestFocus(),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 140,
            child: _CatalogPickerButtonField<String>(
              focusNode: _familyFocus,
              label: 'Familia',
              displayValue: _family,
              dialogTitle: 'Seleccionar familia',
              initialValue: _family,
              options: _familyOptions
                  .map(
                    (value) => _MenudeoPickerOption<String>(
                      value: value,
                      label: value,
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _family = value);
              },
              onSelected: () => _generalFocus.requestFocus(),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 220,
            child: _CatalogPickerButtonField<String>(
              focusNode: _generalFocus,
              label: 'Relacion',
              displayValue:
                  widget.generalMaterials
                      .firstWhere(
                        (row) =>
                            (row['id'] ?? '').toString() == _generalMaterialId,
                        orElse: () => const {},
                      )['name']
                      ?.toString() ??
                  '',
              dialogTitle: 'Seleccionar material general',
              initialValue: _generalMaterialId,
              options: widget.generalMaterials
                  .where((row) => (row['is_active'] ?? true) == true)
                  .map(
                    (row) => _MenudeoPickerOption<String>(
                      value: (row['id'] ?? '').toString(),
                      label: (row['name'] ?? '').toString(),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _generalMaterialId = value);
              },
              onSelected: () => _notesFocus.requestFocus(),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: _isActive ? 'Activo' : 'Inactivo',
                child: Switch(
                  value: _isActive,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 220,
            child: TextField(
              controller: _notesC,
              focusNode: _notesFocus,
              decoration: _catalogInlineFieldDecoration(context, 'Notas'),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterpartySelectionEditRow extends StatefulWidget {
  final int selectedCount;
  final VoidCallback onCancel;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _CounterpartySelectionEditRow({
    required this.selectedCount,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_CounterpartySelectionEditRow> createState() =>
      _CounterpartySelectionEditRowState();
}

class _CounterpartySelectionEditRowState
    extends State<_CounterpartySelectionEditRow> {
  late final TextEditingController _groupC;
  late final TextEditingController _notesC;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _groupC = TextEditingController();
    _notesC = TextEditingController();
  }

  @override
  void dispose() {
    _groupC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSave({
      'group_code': _normalizeName(_groupC.text),
      'notes': _notesC.text.trim(),
      'is_active': _isActive,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final pressedSave =
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed) &&
            event.logicalKey == LogicalKeyboardKey.keyS;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onCancel();
          return KeyEventResult.handled;
        }
        if (pressedSave) {
          _submit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: _CatalogInlineInsertRow(
        contentWidth: _kCounterpartyContentW,
        editing: true,
        statusLabel: 'EDITANDO SELECCION (${widget.selectedCount})',
        actionChild: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _CatalogInlineActionButton(
              onTap: widget.onCancel,
              icon: Icons.close_rounded,
              color: const Color(0xFF8F6D5A),
            ),
            const SizedBox(width: 8),
            _CatalogInlineActionButton(
              onTap: _submit,
              icon: Icons.check_rounded,
              color: const Color(0xFF19C37D),
            ),
          ],
        ),
        children: [
          const _CatalogInlineFieldCell(
            width: 250,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SELECCION MULTIPLE',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const _CatalogInlineFieldCell(
            width: 120,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('—', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 140,
            child: TextField(
              controller: _groupC,
              textCapitalization: TextCapitalization.characters,
              decoration: _catalogInlineFieldDecoration(context, 'Grupo'),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const _CatalogInlineFieldCell(width: 220, child: SizedBox.shrink()),
          _CatalogInlineFieldCell(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: _isActive ? 'Activo' : 'Inactivo',
                child: Switch(
                  value: _isActive,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 260,
            child: TextField(
              controller: _notesC,
              decoration: _catalogInlineFieldDecoration(context, 'Notas'),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialsSelectionEditRow extends StatefulWidget {
  final int selectedCount;
  final VoidCallback onCancel;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _MaterialsSelectionEditRow({
    required this.selectedCount,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_MaterialsSelectionEditRow> createState() =>
      _MaterialsSelectionEditRowState();
}

class _MaterialsSelectionEditRowState
    extends State<_MaterialsSelectionEditRow> {
  late final TextEditingController _notesC;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _notesC = TextEditingController();
  }

  @override
  void dispose() {
    _notesC.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSave({'notes': _notesC.text.trim(), 'is_active': _isActive});
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final pressedSave =
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed) &&
            event.logicalKey == LogicalKeyboardKey.keyS;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onCancel();
          return KeyEventResult.handled;
        }
        if (pressedSave) {
          _submit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: _CatalogInlineInsertRow(
        contentWidth: _kMaterialsContentW,
        editing: true,
        statusLabel: 'EDITANDO SELECCION (${widget.selectedCount})',
        actionChild: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _CatalogInlineActionButton(
              onTap: widget.onCancel,
              icon: Icons.close_rounded,
              color: const Color(0xFF8F6D5A),
            ),
            const SizedBox(width: 8),
            _CatalogInlineActionButton(
              onTap: _submit,
              icon: Icons.check_rounded,
              color: const Color(0xFF19C37D),
            ),
          ],
        ),
        children: [
          const _CatalogInlineFieldCell(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _RowChip(label: 'MULTI', tone: Color(0xFF8E3F2A)),
            ),
          ),
          const _CatalogInlineFieldCell(width: 150, child: SizedBox.shrink()),
          const _CatalogInlineFieldCell(
            width: 240,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SELECCION DE MATERIALES',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const _CatalogInlineFieldCell(width: 140, child: SizedBox.shrink()),
          const _CatalogInlineFieldCell(width: 220, child: SizedBox.shrink()),
          _CatalogInlineFieldCell(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: _isActive ? 'Activo' : 'Inactivo',
                child: Switch(
                  value: _isActive,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 220,
            child: TextField(
              controller: _notesC,
              decoration: _catalogInlineFieldDecoration(context, 'Notas'),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PricesSelectionEditRow extends StatefulWidget {
  final int selectedCount;
  final VoidCallback onCancel;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _PricesSelectionEditRow({
    required this.selectedCount,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_PricesSelectionEditRow> createState() =>
      _PricesSelectionEditRowState();
}

class _PricesSelectionEditRowState extends State<_PricesSelectionEditRow> {
  late final TextEditingController _amountC;
  late final TextEditingController _notesC;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _amountC = TextEditingController();
    _notesC = TextEditingController();
  }

  @override
  void dispose() {
    _amountC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSave({
      'final_price': _amountC.text.trim(),
      'notes': _notesC.text.trim(),
      'is_active': _isActive,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final pressedSave =
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed) &&
            event.logicalKey == LogicalKeyboardKey.keyS;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onCancel();
          return KeyEventResult.handled;
        }
        if (pressedSave) {
          _submit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: _CatalogInlineInsertRow(
        contentWidth: _kPricesContentW,
        editing: true,
        statusLabel: 'EDITANDO SELECCION (${widget.selectedCount})',
        actionChild: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _CatalogInlineActionButton(
              onTap: widget.onCancel,
              icon: Icons.close_rounded,
              color: const Color(0xFF8F6D5A),
            ),
            const SizedBox(width: 8),
            _CatalogInlineActionButton(
              onTap: _submit,
              icon: Icons.check_rounded,
              color: const Color(0xFF19C37D),
            ),
          ],
        ),
        children: [
          const _CatalogInlineFieldCell(
            width: 240,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SELECCION DE PRECIOS',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const _CatalogInlineFieldCell(
            width: 130,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'AUTO',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const _CatalogInlineFieldCell(width: 240, child: SizedBox.shrink()),
          _CatalogInlineFieldCell(
            width: 120,
            child: TextField(
              controller: _amountC,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: _catalogInlineFieldDecoration(context, 'Precio'),
              onSubmitted: (_) => _submit(),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: _isActive ? 'Activo' : 'Inactivo',
                child: Switch(
                  value: _isActive,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ),
            ),
          ),
          _CatalogInlineFieldCell(
            width: 260,
            child: TextField(
              controller: _notesC,
              decoration: _catalogInlineFieldDecoration(context, 'Notas'),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenudeoPickerOption<T> {
  final T value;
  final String label;

  const _MenudeoPickerOption({required this.value, required this.label});
}

Future<T?> _showMenudeoSearchablePickerDialog<T>(
  BuildContext context, {
  required String title,
  required List<_MenudeoPickerOption<T>> options,
  T? initialValue,
  bool allowClear = false,
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) {
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
              .where((o) => o.label.toLowerCase().contains(q.toLowerCase()))
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
                if (filtered.isEmpty) return KeyEventResult.handled;
                final index = (focusedIndex ?? 0).clamp(0, filtered.length - 1);
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
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
                          onChanged: (value) => setLocalState(() => q = value),
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
                      const SizedBox(height: 6),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('Sin resultados'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (_, i) {
                                  final option = filtered[i];
                                  final selected = option.value == initialValue;
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
                                          itemFocusNodes[i - 1].requestFocus();
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
                                              LogicalKeyboardKey.numpadEnter ||
                                          event.logicalKey ==
                                              LogicalKeyboardKey.space) {
                                        Navigator.of(
                                          dialogContext,
                                        ).pop(option.value);
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: ListTile(
                                      dense: true,
                                      selected: selected,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      title: Text(
                                        option.label,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: selected
                                          ? const Icon(Icons.check, size: 18)
                                          : null,
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
          );
        },
      );
    },
  );
}

Future<Set<T>?> _showMenudeoMultiSelectDialog<T>(
  BuildContext context, {
  required String title,
  required List<_MenudeoPickerOption<T>> options,
  Set<T> initialValues = const {},
}) {
  return showDialog<Set<T>>(
    context: context,
    builder: (dialogContext) {
      final searchC = TextEditingController();
      final selected = <T>{...initialValues};
      String q = '';

      return StatefulBuilder(
        builder: (context, setLocalState) {
          final filtered = options
              .where((o) => o.label.toLowerCase().contains(q.toLowerCase()))
              .toList(growable: false);
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
                Navigator.of(dialogContext).pop(selected);
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: searchC,
                        autofocus: true,
                        decoration: contractGlassFieldDecoration(
                          context,
                          hintText: 'Buscar',
                          prefixIcon: const Icon(Icons.search_rounded),
                        ),
                        onChanged: (value) => setLocalState(() => q = value),
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
                                  return CheckboxListTile(
                                    value: checked,
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    title: Text(
                                      option.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onChanged: (value) {
                                      setLocalState(() {
                                        if (value == true) {
                                          selected.add(option.value);
                                        } else {
                                          selected.remove(option.value);
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
                            style: contractSecondaryButtonStyle(context),
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(<T>{}),
                            child: const Text('Limpiar'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: contractPrimaryButtonStyle(context),
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(selected),
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
}

class _CatalogPickerButtonField<T> extends StatelessWidget {
  final FocusNode? focusNode;
  final bool autofocus;
  final String label;
  final String displayValue;
  final String dialogTitle;
  final T? initialValue;
  final List<_MenudeoPickerOption<T>> options;
  final bool allowClear;
  final ValueChanged<T?> onChanged;
  final VoidCallback? onSelected;
  final VoidCallback? onMovePrev;
  final VoidCallback? onMoveNext;
  final VoidCallback? onMoveDown;

  const _CatalogPickerButtonField({
    this.focusNode,
    this.autofocus = false,
    required this.label,
    required this.displayValue,
    required this.dialogTitle,
    required this.initialValue,
    required this.options,
    required this.onChanged,
    this.allowClear = false,
    this.onSelected,
    this.onMovePrev,
    this.onMoveNext,
    this.onMoveDown,
  });

  Future<void> _openPicker(BuildContext context) async {
    final selected = await _showMenudeoSearchablePickerDialog<T>(
      context,
      title: dialogTitle,
      options: options,
      initialValue: initialValue,
      allowClear: allowClear,
    );
    onChanged(selected);
    if (selected != null) {
      onSelected?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      canRequestFocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            onMovePrev != null) {
          onMovePrev!.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
            onMoveNext != null) {
          onMoveNext!.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
            onMoveDown != null) {
          onMoveDown!.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter ||
            event.logicalKey == LogicalKeyboardKey.space) {
          unawaited(_openPicker(context));
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => unawaited(_openPicker(context)),
        child: InputDecorator(
          decoration: contractGlassFieldDecoration(context, hintText: label),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayValue.isEmpty ? label : displayValue,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: displayValue.isEmpty
                        ? const Color(0xFF7D746F)
                        : const Color(0xFF2D2A28),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_drop_down_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogHeaderColumn {
  final String label;
  final double width;
  final VoidCallback? onFilter;
  final bool active;

  const _CatalogHeaderColumn(
    this.label,
    this.width, {
    this.onFilter,
    this.active = false,
  });
}

class _CatalogHeaderRow extends StatelessWidget {
  final List<_CatalogHeaderColumn> columns;

  const _CatalogHeaderRow({required this.columns});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w800);
    return Card(
      elevation: 0,
      color: Colors.black.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = columns.fold<double>(
              0,
              (sum, column) => sum + column.width,
            );
            return SizedBox(
              width: constraints.maxWidth,
              child: ContractGridScaledRow(
                child: SizedBox(
                  width: totalWidth,
                  child: Row(
                    children: [
                      for (final column in columns)
                        SizedBox(
                          width: column.width,
                          child: Row(
                            children: [
                              if (column.onFilter != null) ...[
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: column.onFilter,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 140),
                                    curve: Curves.easeOutCubic,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: column.active
                                          ? const Color(0xFFC96A4A)
                                          : const Color(0xFFF3D9CF),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: column.active
                                            ? const Color(0xFF8E3F2A)
                                            : const Color(0xFFE4B9A8),
                                      ),
                                    ),
                                    child: Icon(
                                      column.active
                                          ? Icons.filter_alt
                                          : Icons.filter_alt_outlined,
                                      size: 15,
                                      color: column.active
                                          ? Colors.white
                                          : const Color(0xFF7A3422),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  column.label,
                                  style: textStyle,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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

class _CatalogTableList extends StatelessWidget {
  final String emptyLabel;
  final double contentWidth;
  final List<Widget> rows;

  const _CatalogTableList({
    required this.emptyLabel,
    required this.contentWidth,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return ContractGlassCard(
        child: Center(
          child: Text(
            emptyLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) => rows[index],
    );
  }
}

class _CatalogTabSurface extends StatelessWidget {
  final Widget child;

  const _CatalogTabSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: child,
    );
  }
}

class _CatalogTableCell {
  final double width;
  final Widget child;

  const _CatalogTableCell._({required this.width, required this.child});

  factory _CatalogTableCell.text({
    required double width,
    required String text,
    bool bold = false,
  }) {
    return _CatalogTableCell._(
      width: width,
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
          color: const Color(0xFF2D2A28),
        ),
      ),
    );
  }

  factory _CatalogTableCell.chip({
    required double width,
    required String label,
    required Color tone,
  }) {
    return _CatalogTableCell._(
      width: width,
      child: Align(
        alignment: Alignment.centerLeft,
        child: _RowChip(label: label, tone: tone),
      ),
    );
  }
}

class _CatalogTableRow extends StatefulWidget {
  final String rowKey;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onPrimaryPointerDown;
  final VoidCallback? onDragEnter;
  final VoidCallback? onPointerEnd;
  final VoidCallback? onSecondarySelection;
  final VoidCallback? onDoubleTap;
  final List<_CatalogTableCell> cells;
  final List<_RowMenuAction> menuItems;
  final Set<int> editableColumns;

  const _CatalogTableRow({
    required this.rowKey,
    required this.selected,
    required this.onTap,
    this.onPrimaryPointerDown,
    this.onDragEnter,
    this.onPointerEnd,
    this.onSecondarySelection,
    this.onDoubleTap,
    required this.cells,
    required this.menuItems,
    this.editableColumns = const <int>{},
  });

  @override
  State<_CatalogTableRow> createState() => _CatalogTableRowState();
}

class _CatalogTableRowState extends State<_CatalogTableRow> {
  bool _hovering = false;
  int? _hoveredEditableColumn;

  Future<void> _openContextMenuAt(Offset globalPosition) async {
    widget.onSecondarySelection?.call();
    final action = await showMenu<_RowMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        for (final item in widget.menuItems)
          PopupMenuItem<_RowMenuAction>(
            value: item,
            child: Row(
              children: [
                Icon(item.icon, size: 18),
                const SizedBox(width: 8),
                Text(item.label),
              ],
            ),
          ),
      ],
    );
    action?.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final selected = widget.selected;
    final softenDividers = _hoveredEditableColumn != null;
    final rowContentWidth = widget.cells.fold<double>(
      _kCatalogActionsW,
      (sum, cell) => sum + cell.width,
    );
    final background = selected
        ? tokens.badgeBackground.withValues(alpha: 0.94)
        : _hovering
        ? Colors.white.withValues(alpha: 0.84)
        : Colors.white.withValues(alpha: 0.66);
    Widget buildCell(int index, _CatalogTableCell cell) {
      final editable = widget.editableColumns.contains(index);
      final hoveredEditable = editable && _hoveredEditableColumn == index;
      final content = Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ContractEditableHoverCapsule(
              hovered: hoveredEditable,
              selectedContext: selected,
              child: cell.child,
            ),
          ),
          Positioned(
            right: 4,
            top: 2,
            bottom: 2,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOutCubic,
              opacity: softenDividers ? 0.0 : 1.0,
              child: Container(
                width: 1,
                decoration: BoxDecoration(
                  color: const Color(0xFFC9D5E2).withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      );
      final cellChild = SizedBox(width: cell.width, child: content);
      if (!editable) {
        return cellChild;
      }
      return MouseRegion(
        onEnter: (_) => setState(() => _hoveredEditableColumn = index),
        onExit: (_) {
          if (_hoveredEditableColumn == index) {
            setState(() => _hoveredEditableColumn = null);
          }
        },
        child: cellChild,
      );
    }

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovering = true);
        widget.onDragEnter?.call();
      },
      onExit: (_) => setState(() => _hovering = false),
      child: Listener(
        onPointerDown: (event) {
          if ((event.buttons & kPrimaryMouseButton) != 0) {
            widget.onPrimaryPointerDown?.call();
          }
        },
        onPointerUp: (_) => widget.onPointerEnd?.call(),
        onPointerCancel: (_) => widget.onPointerEnd?.call(),
        child: Card(
          elevation: 0,
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: selected
                  ? tokens.primaryStrong.withValues(alpha: 0.52)
                  : tokens.border.withValues(alpha: 0.72),
            ),
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
                      onSecondaryTapDown: (details) {
                        unawaited(_openContextMenuAt(details.globalPosition));
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: widget.onTap,
                          onDoubleTap: widget.onDoubleTap,
                          child: SizedBox(
                            width: rowContentWidth,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < widget.cells.length; i++)
                                  buildCell(i, widget.cells[i]),
                                AnchoredActionSlot(
                                  width: _kCatalogActionsW,
                                  trailingWidth: 36,
                                  leading: const SizedBox.shrink(),
                                  trailing: PopupMenuButton<_RowMenuAction>(
                                    tooltip: 'Acciones',
                                    padding: EdgeInsets.zero,
                                    onOpened: widget.onSecondarySelection,
                                    onSelected: (item) => item.onTap(),
                                    itemBuilder: (context) => [
                                      for (final item in widget.menuItems)
                                        PopupMenuItem<_RowMenuAction>(
                                          value: item,
                                          child: Row(
                                            children: [
                                              Icon(item.icon, size: 18),
                                              const SizedBox(width: 8),
                                              Text(item.label),
                                            ],
                                          ),
                                        ),
                                    ],
                                    child: const SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: Center(
                                        child: Icon(Icons.more_horiz_rounded),
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
    );
  }
}

class _CatalogKeyboardActionRow {
  final String key;
  final bool active;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final Future<void> Function()? onDelete;

  const _CatalogKeyboardActionRow({
    required this.key,
    required this.active,
    required this.onEdit,
    required this.onToggleActive,
    this.onDelete,
  });
}

class _RowChip extends StatelessWidget {
  final String label;
  final Color tone;

  const _RowChip({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: tone,
        ),
      ),
    );
  }
}

class _RowMenuAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _RowMenuAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class _CatalogHeaderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Future<void> Function() onTap;

  const _CatalogHeaderButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => unawaited(onTap()),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.46)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: tokens.primaryStrong),
              const SizedBox(width: 10),
              Text(
                label,
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
    );
  }
}

class _CatalogBrand extends StatelessWidget {
  final Animation<double> contentAnim;
  final String title;

  const _CatalogBrand({required this.contentAnim, required this.title});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Opacity(
      opacity: contentAnim.value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: DicsaLogoD(size: 58),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 1,
            height: 48,
            color: tokens.primaryStrong.withValues(alpha: 0.22),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenudeoCatalogBackground extends StatelessWidget {
  const _MenudeoCatalogBackground();

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
