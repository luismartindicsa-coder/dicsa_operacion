import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_navigation.dart';
import '../shared/app_shell.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/editable_hover_capsule.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import '../services/inventory_movements_grid.dart';
import 'menudeo_dashboard_page.dart';
import 'menudeo_delete_confirm_dialog.dart';
import 'menudeo_deposits_expenses_page.dart';
import 'menudeo_filter_widgets.dart';
import 'menudeo_header_brand.dart';
import 'menudeo_price_adjustments_page.dart';
import 'menudeo_session_confirm_dialog.dart';
import 'menudeo_sales_page.dart';
import 'menudeo_tickets_page.dart';
import 'menudeo_theme.dart';

const double _kCatalogActionsW = 86;
const double _kCounterpartyContentW = 1286;
const double _kMaterialsContentW = 1286;
const double _kPricesContentW = 1586;
final Object _kCatalogEditTapRegionGroup = Object();
const List<_MenudeoPickerOption<String>> _kCounterpartyGroupOptions = [
  _MenudeoPickerOption(value: 'PUBLICO GENERAL', label: 'PUBLICO GENERAL'),
  _MenudeoPickerOption(value: 'PROVEEDOR GRANDE', label: 'PROVEEDOR GRANDE'),
  _MenudeoPickerOption(value: 'TRICICLOS', label: 'TRICICLOS'),
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

String _counterpartyKindLabel(String raw) {
  switch (_normalizeName(raw)) {
    case 'SUPPLIER':
      return 'PROVEEDOR';
    case 'CUSTOMER':
      return 'CLIENTE';
    case 'BOTH':
      return 'AMBOS';
    default:
      return _normalizeName(raw);
  }
}

String _priceDirectionLabel(String raw) {
  switch (_normalizeName(raw)) {
    case 'PURCHASE':
      return 'COMPRA';
    case 'SALE':
      return 'VENTA';
    default:
      return _normalizeName(raw);
  }
}

String _defaultPriceDirectionForKind(String rawKind) {
  switch (_normalizeName(rawKind)) {
    case 'CUSTOMER':
      return 'sale';
    case 'SUPPLIER':
      return 'purchase';
    default:
      return 'purchase';
  }
}

String _counterpartyKindShortLabel(String raw) {
  switch (_normalizeName(raw)) {
    case 'SUPPLIER':
      return 'PROVEEDOR';
    case 'CUSTOMER':
      return 'CLIENTE';
    case 'BOTH':
      return 'AMBOS';
    default:
      return _normalizeName(raw);
  }
}

TextInputFormatter _normalizedUppercaseFormatter() {
  return TextInputFormatter.withFunction((oldValue, newValue) {
    final normalized = _stripAccents(newValue.text)
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceFirst(RegExp(r'^ '), '');
    final offset = newValue.selection.baseOffset.clamp(0, normalized.length);
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: offset),
    );
  });
}

List<Map<String, dynamic>> _rowsFrom(dynamic data) {
  return (data as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList(growable: false);
}

class MenudeoCatalogPage extends StatefulWidget {
  final bool instantOpen;

  const MenudeoCatalogPage({super.key, this.instantOpen = false});

  @override
  State<MenudeoCatalogPage> createState() => _MenudeoCatalogPageState();
}

class _MenudeoCatalogPageState extends State<MenudeoCatalogPage> {
  final SupabaseClient _supa = Supabase.instance.client;

  bool _menuOpen = false;
  bool _loading = true;
  final bool _showInactive = false;
  String? _error;
  String? _selectedRowKey;
  String? _selectionAnchorRowKey;
  String? _editingRowKey;
  final Set<String> _bulkSelectedRowKeys = <String>{};
  bool _multiEditMode = false;

  final TextEditingController _counterpartyDraftNameC = TextEditingController();
  final TextEditingController _counterpartyDraftNotesC =
      TextEditingController();
  final TextEditingController _materialDraftNameC = TextEditingController();
  final TextEditingController _materialDraftNotesC = TextEditingController();
  final TextEditingController _priceDraftAmountC = TextEditingController();
  final TextEditingController _priceDraftNotesC = TextEditingController();
  final FocusNode _counterpartyDraftNameFocus = FocusNode();
  final FocusNode _gridRowsFocusNode = FocusNode(debugLabel: 'men_rows_focus');
  final Map<String, GlobalKey> _rowItemKeys = <String, GlobalKey>{};
  final Map<String, GlobalKey<_CounterpartyInlineEditRowState>>
  _counterpartyEditRowKeys =
      <String, GlobalKey<_CounterpartyInlineEditRowState>>{};
  final Map<String, GlobalKey<_GeneralMaterialInlineEditRowState>>
  _generalMaterialEditRowKeys =
      <String, GlobalKey<_GeneralMaterialInlineEditRowState>>{};
  final Map<String, GlobalKey<_CommercialMaterialInlineEditRowState>>
  _commercialMaterialEditRowKeys =
      <String, GlobalKey<_CommercialMaterialInlineEditRowState>>{};
  final Map<String, GlobalKey<_PriceInlineEditRowState>> _priceEditRowKeys =
      <String, GlobalKey<_PriceInlineEditRowState>>{};
  final ScrollController _counterpartyRowsScrollController = ScrollController();
  final ScrollController _materialsRowsScrollController = ScrollController();
  final ScrollController _pricesRowsScrollController = ScrollController();
  final GlobalKey _counterpartyRowsViewportKey = GlobalKey(
    debugLabel: 'men_rows_viewport_counterparties',
  );
  final GlobalKey _materialsRowsViewportKey = GlobalKey(
    debugLabel: 'men_rows_viewport_materials',
  );
  final GlobalKey _pricesRowsViewportKey = GlobalKey(
    debugLabel: 'men_rows_viewport_prices',
  );
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
  final FocusNode _priceDraftDirectionFocus = FocusNode();
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
  String _counterpartyDraftGroup = 'PUBLICO GENERAL';
  String? _counterpartyDraftSiteId;
  String _materialDraftLevel = 'GENERAL';
  String _materialDraftFamily = 'other';
  String? _materialDraftGeneralMaterialId;
  String? _priceDraftCounterpartyId;
  String? _priceDraftGeneralMaterialId;
  String? _priceDraftCommercialMaterialId;
  String _priceDraftDirection = 'purchase';
  bool _insertingCounterparty = false;
  bool _insertingMaterial = false;
  bool _insertingPrice = false;
  final Map<String, Set<String>> _columnValueFilters = <String, Set<String>>{};
  int _activeTabIndex = 0;
  int _currentPage = 0;
  int _pageSize = 40;
  bool _dragSelectionActive = false;
  bool _dragSelectionMoved = false;
  bool _suppressNextRowTap = false;
  bool _suppressNextGridEnter = false;
  bool _pointerDownAdditiveSelection = false;
  List<String> _dragSelectionVisibleKeys = const <String>[];
  Offset? _dragPointerLocal;
  Timer? _dragAutoScrollTimer;
  double _dragAutoScrollVelocity = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAll());
  }

  @override
  void dispose() {
    _counterpartyDraftNameC.dispose();
    _counterpartyDraftNotesC.dispose();
    _materialDraftNameC.dispose();
    _materialDraftNotesC.dispose();
    _priceDraftAmountC.dispose();
    _priceDraftNotesC.dispose();
    _counterpartyDraftNameFocus.dispose();
    _gridRowsFocusNode.dispose();
    _dragAutoScrollTimer?.cancel();
    _counterpartyRowsScrollController.dispose();
    _materialsRowsScrollController.dispose();
    _pricesRowsScrollController.dispose();
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
    _priceDraftDirectionFocus.dispose();
    _priceDraftMaterialFocus.dispose();
    _priceDraftAmountFocus.dispose();
    _priceDraftNotesFocus.dispose();
    super.dispose();
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

  List<T> _pageRows<T>(List<T> rows) {
    if (rows.isEmpty) return <T>[];
    final currentPage = _effectiveCurrentPageFor(rows.length);
    final start = currentPage * _pageSize;
    final end = math.min(start + _pageSize, rows.length);
    return rows.sublist(start, end);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showStub(String label) {
    _toast('$label quedará conectado en la siguiente fase de Menudeo.');
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

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Menudeo':
        unawaited(_goBack());
        return;
      case 'Catálogo':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      case 'Ajuste de precios':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openPriceAdjustmentsPage());
        return;
      case 'Tickets de menudeo':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openTicketsPage());
        return;
      case 'Ventas menudeo':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openSalesPage());
        return;
      case 'Depósitos y gastos':
        if (_menuOpen) setState(() => _menuOpen = false);
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
            'direction': price['direction'] ?? 'purchase',
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
    final pressedSave =
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed) &&
        event.logicalKey == LogicalKeyboardKey.keyS;
    if (pressedSave && _multiEditMode) {
      _saveActiveMultiEdit();
      return KeyEventResult.handled;
    }

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
      if (_isShiftPressed() || _isCtrlOrCmdPressed()) {
        _selectRowRangeTo(nextKey, rows.map((row) => row.key).toList());
      } else {
        _selectSingleRow(nextKey);
      }
      _ensureRowVisible(nextKey);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (index <= 0 && !_isShiftPressed() && !_isCtrlOrCmdPressed()) {
        _focusInsertRowStart();
        return KeyEventResult.handled;
      }
      final nextIndex = index <= 0 ? 0 : index - 1;
      final nextKey = rows[nextIndex].key;
      if (_isShiftPressed() || _isCtrlOrCmdPressed()) {
        _selectRowRangeTo(nextKey, rows.map((row) => row.key).toList());
      } else {
        _selectSingleRow(nextKey);
      }
      _ensureRowVisible(nextKey);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_suppressNextGridEnter) {
        _suppressNextGridEnter = false;
        return KeyEventResult.handled;
      }
      if (_multiEditMode) {
        _saveActiveMultiEdit();
        return KeyEventResult.handled;
      }
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
      if (_editingRowKey != null || _multiEditMode || _hasEditableTextFocus()) {
        return KeyEventResult.ignored;
      }
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

  bool _hasEditableTextFocus() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    if (focusContext.widget is EditableText) return true;
    return focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  Set<String> _currentSelectionKeys() {
    final keys = <String>{..._bulkSelectedRowKeys};
    if (_selectedRowKey != null) keys.add(_selectedRowKey!);
    return keys;
  }

  int get _selectedCount => _currentSelectionKeys().length;

  GlobalKey get _activeRowsViewportKey {
    switch (_activeTabIndex) {
      case 0:
        return _counterpartyRowsViewportKey;
      case 1:
        return _materialsRowsViewportKey;
      default:
        return _pricesRowsViewportKey;
    }
  }

  ScrollController get _activeRowsScrollController {
    switch (_activeTabIndex) {
      case 0:
        return _counterpartyRowsScrollController;
      case 1:
        return _materialsRowsScrollController;
      default:
        return _pricesRowsScrollController;
    }
  }

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
    if (_suppressNextRowTap) {
      _suppressNextRowTap = false;
      _requestGridRowsFocus();
      return;
    }
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

  GlobalKey _rowItemKey(String rowKey) {
    return _rowItemKeys.putIfAbsent(
      rowKey,
      () => GlobalKey(debugLabel: 'men_row_$rowKey'),
    );
  }

  GlobalKey<_CounterpartyInlineEditRowState> _counterpartyEditKey(
    String rowKey,
  ) {
    return _counterpartyEditRowKeys.putIfAbsent(
      rowKey,
      () => GlobalKey<_CounterpartyInlineEditRowState>(
        debugLabel: 'men_cp_edit_$rowKey',
      ),
    );
  }

  GlobalKey<_GeneralMaterialInlineEditRowState> _generalMaterialEditKey(
    String rowKey,
  ) {
    return _generalMaterialEditRowKeys.putIfAbsent(
      rowKey,
      () => GlobalKey<_GeneralMaterialInlineEditRowState>(
        debugLabel: 'men_matg_edit_$rowKey',
      ),
    );
  }

  GlobalKey<_CommercialMaterialInlineEditRowState> _commercialMaterialEditKey(
    String rowKey,
  ) {
    return _commercialMaterialEditRowKeys.putIfAbsent(
      rowKey,
      () => GlobalKey<_CommercialMaterialInlineEditRowState>(
        debugLabel: 'men_matc_edit_$rowKey',
      ),
    );
  }

  GlobalKey<_PriceInlineEditRowState> _priceEditKey(String rowKey) {
    return _priceEditRowKeys.putIfAbsent(
      rowKey,
      () => GlobalKey<_PriceInlineEditRowState>(
        debugLabel: 'men_price_edit_$rowKey',
      ),
    );
  }

  bool _isInlineRowEditing(String rowKey) {
    return _editingRowKey == rowKey ||
        (_multiEditMode &&
            _selectedCount > 1 &&
            _currentSelectionKeys().contains(rowKey));
  }

  void _ensureRowVisible(String rowKey) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rowContext = _rowItemKey(rowKey).currentContext;
      if (rowContext == null) return;
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    });
  }

  void _focusFirstVisibleRow(List<String> visibleKeys) {
    if (visibleKeys.isEmpty) return;
    FocusScope.of(context).unfocus();
    _selectSingleRow(visibleKeys.first);
    _ensureRowVisible(visibleKeys.first);
    _requestGridRowsFocus();
  }

  void _beginDragSelection(String rowKey, List<String> visibleKeys) {
    if (_editingRowKey != null || _multiEditMode) return;
    if (_isCtrlOrCmdPressed() || _isShiftPressed()) return;
    _dragSelectionActive = true;
    _dragSelectionMoved = false;
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
    _dragSelectionMoved = true;
    _selectRowRangeTo(rowKey, _dragSelectionVisibleKeys);
  }

  void _endDragSelection() {
    _suppressNextRowTap = _dragSelectionMoved;
    _dragSelectionActive = false;
    _dragSelectionMoved = false;
    _dragPointerLocal = null;
    _dragAutoScrollVelocity = 0;
    _dragAutoScrollTimer?.cancel();
    _dragAutoScrollTimer = null;
    _pointerDownAdditiveSelection = false;
    _dragSelectionVisibleKeys = const <String>[];
  }

  int? _rowIndexAtGlobalPosition(Offset globalPosition) {
    final visibleKeys = _dragSelectionVisibleKeys;
    for (var i = 0; i < visibleKeys.length; i++) {
      final context = _rowItemKey(visibleKeys[i]).currentContext;
      if (context == null) continue;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final origin = box.localToGlobal(Offset.zero);
      final rect = origin & box.size;
      if (rect.contains(globalPosition)) return i;
    }
    return null;
  }

  void _selectDraggedRangeByIndex(int currentIndex) {
    final visibleKeys = _dragSelectionVisibleKeys;
    final anchorKey = _selectionAnchorRowKey ?? _selectedRowKey;
    if (visibleKeys.isEmpty || anchorKey == null) return;
    final anchorIndex = visibleKeys.indexOf(anchorKey);
    if (anchorIndex == -1) return;
    final start = math.min(anchorIndex, currentIndex);
    final end = math.max(anchorIndex, currentIndex);
    _selectRowRangeTo(visibleKeys[currentIndex], visibleKeys);
    _bulkSelectedRowKeys
      ..clear()
      ..addAll(visibleKeys.sublist(start, end + 1));
  }

  Offset? _globalToRowsLocal(Offset globalPosition) {
    final box =
        _activeRowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.globalToLocal(globalPosition);
  }

  int? _rowIndexForDragPosition(Offset globalPosition) {
    final exactIndex = _rowIndexAtGlobalPosition(globalPosition);
    if (exactIndex != null) return exactIndex;
    final visibleKeys = _dragSelectionVisibleKeys;
    final local = _globalToRowsLocal(globalPosition);
    if (visibleKeys.isEmpty || local == null) return null;
    final box =
        _activeRowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    if (local.dy < 0) return 0;
    if (local.dy > box.size.height) return visibleKeys.length - 1;
    return null;
  }

  void _handleRowsPointerDown(
    PointerDownEvent event,
    List<String> visibleKeys,
  ) {
    _pointerDownAdditiveSelection = _isCtrlOrCmdPressed() || _isShiftPressed();
    if (event.kind != PointerDeviceKind.mouse ||
        event.buttons != kPrimaryMouseButton ||
        _pointerDownAdditiveSelection) {
      return;
    }
    _dragSelectionVisibleKeys = visibleKeys;
    final rowIndex = _rowIndexAtGlobalPosition(event.position);
    if (rowIndex == null) return;
    _dragSelectionActive = true;
    _dragSelectionMoved = false;
    _dragPointerLocal = _globalToRowsLocal(event.position);
    _updateDragAutoScroll();
    _selectSingleRow(visibleKeys[rowIndex]);
    _requestGridRowsFocus();
  }

  void _handleRowsPointerMove(PointerMoveEvent event) {
    if (!_dragSelectionActive) return;
    _dragPointerLocal = _globalToRowsLocal(event.position);
    _updateDragAutoScroll();
    final rowIndex = _rowIndexForDragPosition(event.position);
    if (rowIndex == null) return;
    _dragSelectionMoved = true;
    _selectDraggedRangeByIndex(rowIndex);
  }

  void _updateDragAutoScroll() {
    if (!_dragSelectionActive || _dragPointerLocal == null) {
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final box =
        _activeRowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
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
      (_) => _tickDragAutoScroll(),
    );
  }

  void _tickDragAutoScroll() {
    if (!_dragSelectionActive ||
        _dragAutoScrollVelocity == 0 ||
        !_activeRowsScrollController.hasClients) {
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final position = _activeRowsScrollController.position;
    final next = (position.pixels + _dragAutoScrollVelocity).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) return;
    _activeRowsScrollController.jumpTo(next);
    final pointerLocal = _dragPointerLocal;
    if (pointerLocal == null) return;
    final box =
        _activeRowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final clampedLocal = Offset(
      pointerLocal.dx.clamp(0.0, box.size.width),
      pointerLocal.dy.clamp(0.0, box.size.height),
    );
    final global = box.localToGlobal(clampedLocal);
    final rowIndex = _rowIndexForDragPosition(global);
    if (rowIndex != null) {
      _dragSelectionMoved = true;
      _selectDraggedRangeByIndex(rowIndex);
    }
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
    _requestGridRowsFocus();
  }

  void _cancelMultiEdit() {
    if (!mounted) return;
    setState(() => _multiEditMode = false);
  }

  void _cancelActiveMultiEdit() {
    for (final rowKey in _currentSelectionKeys()) {
      if (_activeTabIndex == 0) {
        _counterpartyEditRowKeys[rowKey]?.currentState?.cancelFromParent();
      } else if (_activeTabIndex == 1) {
        _generalMaterialEditRowKeys[rowKey]?.currentState?.cancelFromParent();
        _commercialMaterialEditRowKeys[rowKey]?.currentState
            ?.cancelFromParent();
      } else {
        _priceEditRowKeys[rowKey]?.currentState?.cancelFromParent();
      }
    }
    _cancelMultiEdit();
    _requestGridRowsFocus();
  }

  void _saveActiveMultiEdit() {
    for (final rowKey in _currentSelectionKeys()) {
      if (_activeTabIndex == 0) {
        _counterpartyEditRowKeys[rowKey]?.currentState?.submitFromParent();
      } else if (_activeTabIndex == 1) {
        _generalMaterialEditRowKeys[rowKey]?.currentState?.submitFromParent();
        _commercialMaterialEditRowKeys[rowKey]?.currentState
            ?.submitFromParent();
      } else {
        _priceEditRowKeys[rowKey]?.currentState?.submitFromParent();
      }
    }
    _requestGridRowsFocus();
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
          'direccion',
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
                _priceDirectionLabel((row['direction'] ?? '').toString()),
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
    final ok = await showMenudeoDeleteConfirmDialog(
      context,
      title: title,
      message: '¿Seguro que deseas eliminar "$label"?',
      impactLabel: '"$label" saldrá del catálogo actual.',
      subtitle: 'Confirma la baja del registro visible.',
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

  void _resetCounterpartyDraft() {
    _counterpartyDraftNameC.clear();
    _counterpartyDraftGroup = 'PUBLICO GENERAL';
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
      _suppressNextGridEnter = true;
      _clearSelection();
      await _loadAll(showLoader: false);
      _focusInsertRowStart();
    } on PostgrestException catch (e) {
      _toast('No se pudo guardar el material: ${e.message}');
    } finally {
      if (mounted) setState(() => _insertingMaterial = false);
    }
  }

  Future<void> _insertCounterpartyInline() async {
    if (_insertingCounterparty) return;
    final name = _normalizeName(_counterpartyDraftNameC.text);
    final groupCode = _normalizeName(_counterpartyDraftGroup);
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
      _suppressNextGridEnter = true;
      _clearSelection();
      _toast('Contraparte agregada');
      await _loadAll(showLoader: false);
      _focusInsertRowStart();
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
    _priceDraftDirection = 'purchase';
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
        'direction': _priceDraftDirection,
        'material_label_snapshot': materialLabel,
        'final_price': price,
        'notes': _priceDraftNotesC.text.trim().isEmpty
            ? null
            : _priceDraftNotesC.text.trim(),
        'is_active': true,
      });
      _resetPriceDraft();
      _suppressNextGridEnter = true;
      _clearSelection();
      _toast('Precio agregado');
      await _loadAll(showLoader: false);
      _focusInsertRowStart();
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
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape && _menuOpen) {
            setState(() => _menuOpen = false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AppShell(
          background: const _MenudeoCatalogBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 6,
          padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
          leadingBuilder: (_, _) => _CatalogHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, animation) =>
              MenudeoHeaderBrand(contentAnim: animation, title: 'Catálogo'),
          trailingBuilder: (_, _) => _CatalogHeaderButton(
            label: 'Cerrar sesión',
            icon: Icons.logout_rounded,
            onTap: _logout,
          ),
          child: Stack(
            children: [
              _buildBody(context),
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
                  child: _CatalogSidePanel(onNavigate: _handleNavigationAction),
                ),
              ),
            ],
          ),
        ),
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
            'counterparty_kind': _counterpartyKindLabel(
              (row['kind'] ?? '').toString(),
            ),
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
            'price_kind': _counterpartyKindLabel(
              (row['kind'] ?? '').toString(),
            ),
            'price_group': (row['group_code'] ?? '').toString(),
            'price_direction': _priceDirectionLabel(
              (row['direction'] ?? '').toString(),
            ),
            'price_material': (row['material_label_snapshot'] ?? '').toString(),
            'price_amount': (row['final_price'] ?? '').toString(),
            'price_status': _isActive(row, key: 'price_active')
                ? 'ACTIVO'
                : 'INACTIVO',
          });
        })
        .toList(growable: false);
    final materialRows = <Map<String, dynamic>>[
      ...filteredGeneralRows.map((row) => {...row, '_level': 'GENERAL'}),
      ...filteredCommercialRows.map((row) => {...row, '_level': 'COMERCIAL'}),
    ];
    final visibleCounterpartyRows = _pageRows(counterpartyRows);
    final visibleMaterialRows = _pageRows(materialRows);
    final visibleGeneralRows = visibleMaterialRows
        .where((row) => row['_level'] == 'GENERAL')
        .map((row) {
          final copy = <String, dynamic>{...row};
          copy.remove('_level');
          return copy;
        })
        .toList(growable: false);
    final visibleCommercialRows = visibleMaterialRows
        .where((row) => row['_level'] == 'COMERCIAL')
        .map((row) {
          final copy = <String, dynamic>{...row};
          copy.remove('_level');
          return copy;
        })
        .toList(growable: false);
    final visiblePriceRows = _pageRows(priceRows);
    final currentTabRowCount = switch (_activeTabIndex) {
      0 => counterpartyRows.length,
      1 => materialRows.length,
      _ => priceRows.length,
    };
    final currentPage = _effectiveCurrentPageFor(currentTabRowCount);
    final totalPages = _totalPagesFor(currentTabRowCount);
    final keyboardRows = _buildKeyboardRows(
      counterpartyRows: _activeTabIndex == 0
          ? visibleCounterpartyRows
          : const [],
      generalRows: _activeTabIndex == 1 ? visibleGeneralRows : const [],
      commercialRows: _activeTabIndex == 1 ? visibleCommercialRows : const [],
      priceRows: _activeTabIndex == 2 ? visiblePriceRows : const [],
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
                              _currentPage = 0;
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
                                _buildCounterpartiesTab(
                                  counterpartyRows,
                                  visibleCounterpartyRows,
                                ),
                                _buildMaterialsTab(
                                  filteredGeneralRows,
                                  filteredCommercialRows,
                                  visibleMaterialRows,
                                ),
                                _buildPricesTab(priceRows, visiblePriceRows),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: MenudeoGridPager(
                              currentPage: currentPage,
                              totalPages: totalPages,
                              pageSize: _pageSize,
                              totalRows: currentTabRowCount,
                              onPrevious: currentPage > 0
                                  ? () => setState(
                                      () => _currentPage = currentPage - 1,
                                    )
                                  : null,
                              onNext: currentPage < totalPages - 1
                                  ? () => setState(
                                      () => _currentPage = currentPage + 1,
                                    )
                                  : null,
                              onPageSizeChanged: (value) {
                                setState(() {
                                  _pageSize = value;
                                  _currentPage = 0;
                                });
                              },
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

  Widget _buildCounterpartiesTab(
    List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> visibleRows,
  ) {
    final counterpartyRowKeys = visibleRows
        .map((row) => 'cp:${(row['id'] ?? '').toString()}')
        .toList(growable: false);
    return _CatalogTabSurface(
      child: Column(
        children: [
          _CatalogHeaderRow(
            columns: [
              _CatalogHeaderColumn(
                'CONTRAPARTE',
                220,
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
                220,
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
                220,
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
                100,
                active: _hasActiveFilter('counterparty_status'),
                onFilter: () => _openColumnFilter(
                  columnId: 'counterparty_status',
                  title: 'Filtrar estado',
                  values: rows
                      .map((row) => _isActive(row) ? 'ACTIVO' : 'INACTIVO')
                      .toList(),
                ),
              ),
              _CatalogHeaderColumn('NOTAS', 220),
              _CatalogHeaderColumn('', _kCatalogActionsW),
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
                width: 220,
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
                    inputFormatters: [_normalizedUppercaseFormatter()],
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
                width: 220,
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
                width: 220,
                child: _CatalogPickerButtonField<String>(
                  focusNode: _counterpartyDraftGroupFocus,
                  label: 'Grupo',
                  displayValue: _counterpartyDraftGroup,
                  dialogTitle: 'Seleccionar grupo',
                  initialValue: _counterpartyDraftGroup,
                  options: _kCounterpartyGroupOptions,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _counterpartyDraftGroup = value);
                  },
                  onMovePrev: () => _counterpartyDraftKindFocus.requestFocus(),
                  onMoveNext: () => _counterpartyDraftSiteFocus.requestFocus(),
                  onMoveDown: () => _focusFirstVisibleRow(counterpartyRowKeys),
                  onSelected: () => _counterpartyDraftSiteFocus.requestFocus(),
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
                width: 100,
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
          const SizedBox(height: 12),
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) =>
                  _handleRowsPointerDown(event, counterpartyRowKeys),
              onPointerMove: _handleRowsPointerMove,
              onPointerUp: (_) => _endDragSelection(),
              onPointerCancel: (_) => _endDragSelection(),
              child: _CatalogTableList(
                emptyLabel: 'No hay contrapartes para mostrar.',
                contentWidth: _kCounterpartyContentW,
                controller: _counterpartyRowsScrollController,
                viewportKey: _counterpartyRowsViewportKey,
                rows: visibleRows
                    .map((row) {
                      final rowKey = 'cp:${(row['id'] ?? '').toString()}';
                      if (_isInlineRowEditing(rowKey)) {
                        return KeyedSubtree(
                          key: _rowItemKey(rowKey),
                          child: _CounterpartyInlineEditRow(
                            key: _counterpartyEditKey(rowKey),
                            row: row,
                            sites: _sites,
                            onCancel: _multiEditMode
                                ? _cancelActiveMultiEdit
                                : _cancelInlineEdit,
                            onSave: (payload) =>
                                _saveCounterpartyInline(row, payload),
                          ),
                        );
                      }
                      return KeyedSubtree(
                        key: _rowItemKey(rowKey),
                        child: _CatalogTableRow(
                          rowKey: rowKey,
                          selected: _currentSelectionKeys().contains(rowKey),
                          onTap: () =>
                              _handleRowSelection(rowKey, counterpartyRowKeys),
                          onPrimaryPointerDown: () =>
                              _beginDragSelection(rowKey, counterpartyRowKeys),
                          onDragEnter: () => _updateDragSelection(rowKey),
                          onPointerEnd: _endDragSelection,
                          onSecondarySelection: () =>
                              _handleRowSecondarySelection(
                                rowKey,
                                counterpartyRowKeys,
                              ),
                          onDoubleTap: () => _startInlineEdit(rowKey),
                          editableColumns: const {0, 1, 2, 3, 4, 5},
                          cells: [
                            _CatalogTableCell.text(
                              width: 220,
                              text: (row['name'] ?? '').toString(),
                              bold: true,
                            ),
                            _CatalogTableCell.text(
                              width: 220,
                              text: _counterpartyKindLabel(
                                (row['kind'] ?? '').toString(),
                              ),
                            ),
                            _CatalogTableCell.chip(
                              width: 220,
                              label: (row['group_code'] ?? '').toString(),
                              tone: const Color(0xFF8E3F2A),
                            ),
                            _CatalogTableCell.text(
                              width: 220,
                              text:
                                  _siteLabel(row['site_id']?.toString()) ?? '—',
                            ),
                            _CatalogTableCell.chip(
                              width: 100,
                              label: _isActive(row) ? 'ACTIVO' : 'INACTIVO',
                              tone: _isActive(row)
                                  ? const Color(0xFF2F7D57)
                                  : const Color(0xFF8F6D5A),
                            ),
                            _CatalogTableCell.text(
                              width: 220,
                              text:
                                  (row['notes'] ?? '').toString().trim().isEmpty
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
                                      label: 'Guardar selección',
                                      icon: Icons.check_rounded,
                                      onTap: _saveActiveMultiEdit,
                                    ),
                                  if (_multiEditMode)
                                    _RowMenuAction(
                                      label: 'Cancelar edición',
                                      icon: Icons.close_rounded,
                                      onTap: _cancelActiveMultiEdit,
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
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsTab(
    List<Map<String, dynamic>> generalRows,
    List<Map<String, dynamic>> commercialRows,
    List<Map<String, dynamic>> visibleMaterialRows,
  ) {
    final materialRowKeys = visibleMaterialRows
        .map(
          (row) =>
              '${row['_level'] == 'GENERAL' ? 'matg' : 'matc'}:${(row['id'] ?? '').toString()}',
        )
        .toList(growable: false);
    return _CatalogTabSurface(
      child: Column(
        children: [
          _CatalogHeaderRow(
            columns: [
              _CatalogHeaderColumn(
                'NIVEL',
                220,
                active: _hasActiveFilter('material_level'),
                onFilter: () => _openColumnFilter(
                  columnId: 'material_level',
                  title: 'Filtrar nivel',
                  values: const ['GENERAL', 'COMERCIAL'],
                ),
              ),
              _CatalogHeaderColumn(
                'MATERIAL',
                220,
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
                220,
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
                100,
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
              _CatalogHeaderColumn('', _kCatalogActionsW),
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
                width: 220,
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
                width: 220,
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
                    inputFormatters: [_normalizedUppercaseFormatter()],
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
                width: 220,
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
                width: 100,
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
          const SizedBox(height: 12),
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) =>
                  _handleRowsPointerDown(event, materialRowKeys),
              onPointerMove: _handleRowsPointerMove,
              onPointerUp: (_) => _endDragSelection(),
              onPointerCancel: (_) => _endDragSelection(),
              child: _CatalogTableList(
                emptyLabel: 'No hay materiales para mostrar.',
                contentWidth: _kMaterialsContentW,
                controller: _materialsRowsScrollController,
                viewportKey: _materialsRowsViewportKey,
                rows: visibleMaterialRows
                    .map((row) {
                      final rowKey =
                          '${row['_level'] == 'GENERAL' ? 'matg' : 'matc'}:${(row['id'] ?? '').toString()}';
                      if (_isInlineRowEditing(rowKey)) {
                        if (row['_level'] == 'GENERAL') {
                          return KeyedSubtree(
                            key: _rowItemKey(rowKey),
                            child: _GeneralMaterialInlineEditRow(
                              key: _generalMaterialEditKey(rowKey),
                              row: row,
                              onCancel: _multiEditMode
                                  ? _cancelActiveMultiEdit
                                  : _cancelInlineEdit,
                              onSave: (payload) =>
                                  _saveGeneralMaterialInline(row, payload),
                            ),
                          );
                        }
                        return KeyedSubtree(
                          key: _rowItemKey(rowKey),
                          child: _CommercialMaterialInlineEditRow(
                            key: _commercialMaterialEditKey(rowKey),
                            row: row,
                            generalMaterials: _generalMaterials,
                            onCancel: _multiEditMode
                                ? _cancelActiveMultiEdit
                                : _cancelInlineEdit,
                            onSave: (payload) =>
                                _saveCommercialMaterialInline(row, payload),
                          ),
                        );
                      }
                      return KeyedSubtree(
                        key: _rowItemKey(rowKey),
                        child: _CatalogTableRow(
                          rowKey: rowKey,
                          selected: _currentSelectionKeys().contains(rowKey),
                          onTap: () =>
                              _handleRowSelection(rowKey, materialRowKeys),
                          onPrimaryPointerDown: () =>
                              _beginDragSelection(rowKey, materialRowKeys),
                          onDragEnter: () => _updateDragSelection(rowKey),
                          onPointerEnd: _endDragSelection,
                          onSecondarySelection: () =>
                              _handleRowSecondarySelection(
                                rowKey,
                                materialRowKeys,
                              ),
                          onDoubleTap: () => _startInlineEdit(rowKey),
                          editableColumns: const {1, 2, 3, 4, 5},
                          cells: [
                            _CatalogTableCell.chip(
                              width: 220,
                              label: (row['_level'] ?? '').toString(),
                              tone: row['_level'] == 'GENERAL'
                                  ? const Color(0xFF8E3F2A)
                                  : const Color(0xFFE89A5B),
                            ),
                            _CatalogTableCell.text(
                              width: 220,
                              text: (row['name'] ?? '').toString(),
                              bold: true,
                            ),
                            _CatalogTableCell.text(
                              width: 220,
                              text: row['_level'] == 'GENERAL'
                                  ? '—'
                                  : (row['family'] ?? '').toString(),
                            ),
                            _CatalogTableCell.text(
                              width: 220,
                              text: row['_level'] == 'GENERAL'
                                  ? 'Catalogo base'
                                  : (_generalMaterialLabel(
                                          row['general_material_id']
                                              ?.toString(),
                                        ) ??
                                        '—'),
                            ),
                            _CatalogTableCell.chip(
                              width: 100,
                              label: _isActive(row) ? 'ACTIVO' : 'INACTIVO',
                              tone: _isActive(row)
                                  ? const Color(0xFF2F7D57)
                                  : const Color(0xFF8F6D5A),
                            ),
                            _CatalogTableCell.text(
                              width: 220,
                              text:
                                  (row['notes'] ?? '').toString().trim().isEmpty
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
                                      label: 'Guardar selección',
                                      icon: Icons.check_rounded,
                                      onTap: _saveActiveMultiEdit,
                                    ),
                                  if (_multiEditMode)
                                    _RowMenuAction(
                                      label: 'Cancelar edición',
                                      icon: Icons.close_rounded,
                                      onTap: _cancelActiveMultiEdit,
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
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricesTab(
    List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> visibleRows,
  ) {
    final priceRowKeys = visibleRows
        .map((row) => 'price:${(row['price_id'] ?? '').toString()}')
        .toList(growable: false);
    final selectedDraftCounterparty = _counterparties.firstWhere(
      (row) => (row['id'] ?? '').toString() == _priceDraftCounterpartyId,
      orElse: () => const <String, dynamic>{},
    );
    final draftCounterpartyKind = _counterpartyKindShortLabel(
      (selectedDraftCounterparty['kind'] ?? '').toString(),
    );
    final draftCounterpartyGroup =
        (selectedDraftCounterparty['group_code'] ?? '').toString().trim();
    return _CatalogTabSurface(
      child: Column(
        children: [
          _CatalogHeaderRow(
            columns: [
              _CatalogHeaderColumn(
                'CONTRAPARTE',
                220,
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
                'TIPO',
                150,
                active: _hasActiveFilter('price_kind'),
                onFilter: () => _openColumnFilter(
                  columnId: 'price_kind',
                  title: 'Filtrar tipo',
                  values: rows
                      .map(
                        (row) => _counterpartyKindLabel(
                          (row['kind'] ?? '').toString(),
                        ),
                      )
                      .toList(),
                ),
              ),
              _CatalogHeaderColumn(
                'GRUPO',
                220,
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
                'DIRECCION',
                150,
                active: _hasActiveFilter('price_direction'),
                onFilter: () => _openColumnFilter(
                  columnId: 'price_direction',
                  title: 'Filtrar dirección',
                  values: rows
                      .map(
                        (row) => _priceDirectionLabel(
                          (row['direction'] ?? '').toString(),
                        ),
                      )
                      .toList(),
                ),
              ),
              _CatalogHeaderColumn(
                'MATERIAL',
                220,
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
                220,
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
                100,
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
              _CatalogHeaderColumn('NOTAS', 220),
              _CatalogHeaderColumn('', _kCatalogActionsW),
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
                width: 220,
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
                    setState(() {
                      _priceDraftCounterpartyId = value;
                      final counterparty = _counterparties.firstWhere(
                        (row) => (row['id'] ?? '').toString() == value,
                        orElse: () => const <String, dynamic>{},
                      );
                      _priceDraftDirection = _defaultPriceDirectionForKind(
                        (counterparty['kind'] ?? '').toString(),
                      );
                    });
                  },
                  onMoveNext: () => _priceDraftDirectionFocus.requestFocus(),
                  onMoveDown: () => _focusFirstVisibleRow(priceRowKeys),
                  onSelected: () => _priceDraftDirectionFocus.requestFocus(),
                ),
              ),
              _CatalogInlineFieldCell(
                width: 150,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    draftCounterpartyKind.isEmpty
                        ? 'AUTO'
                        : draftCounterpartyKind,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              _CatalogInlineFieldCell(
                width: 220,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    draftCounterpartyGroup.isEmpty
                        ? 'AUTO'
                        : draftCounterpartyGroup,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              _CatalogInlineFieldCell(
                width: 150,
                child: _CatalogPickerButtonField<String>(
                  focusNode: _priceDraftDirectionFocus,
                  label: 'Dirección',
                  displayValue: _priceDirectionLabel(_priceDraftDirection),
                  dialogTitle: 'Seleccionar dirección',
                  initialValue: _priceDraftDirection,
                  options: const [
                    _MenudeoPickerOption(value: 'purchase', label: 'COMPRA'),
                    _MenudeoPickerOption(value: 'sale', label: 'VENTA'),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _priceDraftDirection = value);
                  },
                  onMovePrev: () => _priceDraftCounterpartyFocus.requestFocus(),
                  onMoveNext: () => _priceDraftMaterialFocus.requestFocus(),
                  onMoveDown: () => _focusFirstVisibleRow(priceRowKeys),
                  onSelected: () => _priceDraftMaterialFocus.requestFocus(),
                ),
              ),
              _CatalogInlineFieldCell(
                width: 220,
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
                  onMovePrev: () => _priceDraftDirectionFocus.requestFocus(),
                  onMoveNext: () => _priceDraftAmountFocus.requestFocus(),
                  onMoveDown: () => _focusFirstVisibleRow(priceRowKeys),
                  onSelected: () => _priceDraftAmountFocus.requestFocus(),
                ),
              ),
              _CatalogInlineFieldCell(
                width: 220,
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
                width: 100,
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
          const SizedBox(height: 12),
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) =>
                  _handleRowsPointerDown(event, priceRowKeys),
              onPointerMove: _handleRowsPointerMove,
              onPointerUp: (_) => _endDragSelection(),
              onPointerCancel: (_) => _endDragSelection(),
              child: _CatalogTableList(
                emptyLabel: 'No hay precios para mostrar.',
                contentWidth: _kPricesContentW,
                controller: _pricesRowsScrollController,
                viewportKey: _pricesRowsViewportKey,
                rows: visibleRows
                    .map((row) {
                      final rowKey =
                          'price:${(row['price_id'] ?? '').toString()}';
                      if (_isInlineRowEditing(rowKey)) {
                        return KeyedSubtree(
                          key: _rowItemKey(rowKey),
                          child: _PriceInlineEditRow(
                            key: _priceEditKey(rowKey),
                            row: row,
                            counterparties: _counterparties,
                            generalMaterials: _generalMaterials,
                            commercialMaterials: _commercialMaterials,
                            onCancel: _multiEditMode
                                ? _cancelActiveMultiEdit
                                : _cancelInlineEdit,
                            onSave: (payload) => _savePriceInline(row, payload),
                          ),
                        );
                      }
                      return KeyedSubtree(
                        key: _rowItemKey(rowKey),
                        child: _CatalogTableRow(
                          rowKey: rowKey,
                          selected: _currentSelectionKeys().contains(rowKey),
                          onTap: () =>
                              _handleRowSelection(rowKey, priceRowKeys),
                          onPrimaryPointerDown: () =>
                              _beginDragSelection(rowKey, priceRowKeys),
                          onDragEnter: () => _updateDragSelection(rowKey),
                          onPointerEnd: _endDragSelection,
                          onSecondarySelection: () =>
                              _handleRowSecondarySelection(
                                rowKey,
                                priceRowKeys,
                              ),
                          onDoubleTap: () => _startInlineEdit(rowKey),
                          editableColumns: const {0, 3, 4, 5, 6, 7},
                          cells: [
                            _CatalogTableCell.text(
                              width: 220,
                              text: (row['counterparty_name'] ?? '').toString(),
                              bold: true,
                            ),
                            _CatalogTableCell.chip(
                              width: 150,
                              label: _counterpartyKindLabel(
                                (row['kind'] ?? '').toString(),
                              ),
                              tone: const Color(0xFF8E3F2A),
                            ),
                            _CatalogTableCell.chip(
                              width: 220,
                              label: (row['group_code'] ?? '').toString(),
                              tone: const Color(0xFFB65C2A),
                            ),
                            _CatalogTableCell.chip(
                              width: 150,
                              label: _priceDirectionLabel(
                                (row['direction'] ?? '').toString(),
                              ),
                              tone:
                                  (row['direction'] ?? '').toString() == 'sale'
                                  ? const Color(0xFF2F7D57)
                                  : const Color(0xFF8E3F2A),
                            ),
                            _CatalogTableCell.text(
                              width: 220,
                              text: (row['material_label_snapshot'] ?? '')
                                  .toString(),
                            ),
                            _CatalogTableCell.text(
                              width: 220,
                              text:
                                  '\$${(row['final_price'] ?? '').toString()}',
                              bold: true,
                            ),
                            _CatalogTableCell.chip(
                              width: 100,
                              label: _isActive(row, key: 'price_active')
                                  ? 'ACTIVO'
                                  : 'INACTIVO',
                              tone: _isActive(row, key: 'price_active')
                                  ? const Color(0xFF2F7D57)
                                  : const Color(0xFF8F6D5A),
                            ),
                            _CatalogTableCell.text(
                              width: 220,
                              text:
                                  (row['notes'] ?? '').toString().trim().isEmpty
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
                                      label: 'Guardar selección',
                                      icon: Icons.check_rounded,
                                      onTap: _saveActiveMultiEdit,
                                    ),
                                  if (_multiEditMode)
                                    _RowMenuAction(
                                      label: 'Cancelar edición',
                                      icon: Icons.close_rounded,
                                      onTap: _cancelActiveMultiEdit,
                                    ),
                                  _RowMenuAction(
                                    label: 'Eliminar selección',
                                    icon: Icons.delete_outline_rounded,
                                    onTap: () => _deleteSelectedRows(
                                      _buildKeyboardRows(
                                        counterpartyRows: const [],
                                        generalRows: const [],
                                        commercialRows: const [],
                                        priceRows: rows,
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
                                    label: _isActive(row, key: 'price_active')
                                        ? 'Desactivar'
                                        : 'Activar',
                                    icon: _isActive(row, key: 'price_active')
                                        ? Icons.toggle_off_rounded
                                        : Icons.toggle_on_rounded,
                                    onTap: () => _setActive(
                                      table: 'men_counterparty_material_prices',
                                      id: (row['price_id'] ?? '').toString(),
                                      isActive: !_isActive(
                                        row,
                                        key: 'price_active',
                                      ),
                                      successLabel:
                                          _isActive(row, key: 'price_active')
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
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
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
    super.key,
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
  late final TextEditingController _notesC;
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _kindFocus = FocusNode();
  final FocusNode _groupFocus = FocusNode();
  final FocusNode _siteFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();
  late String _kind;
  late String _group;
  String? _siteId;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: (widget.row['name'] ?? '').toString());
    _notesC = TextEditingController(
      text: (widget.row['notes'] ?? '').toString(),
    );
    _kind = (widget.row['kind'] ?? 'supplier').toString();
    _group = (widget.row['group_code'] ?? '').toString().trim();
    _siteId = widget.row['site_id']?.toString();
    _isActive = (widget.row['is_active'] ?? true) == true;
  }

  @override
  void dispose() {
    _nameC.dispose();
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
      'group_code': _normalizeName(_group),
      'kind': _kind,
      'site_id': _siteId,
      'notes': _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
      'is_active': _isActive,
    });
  }

  void submitFromParent() => _submit();

  void cancelFromParent() => widget.onCancel();

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _kCatalogEditTapRegionGroup,
      onTapOutside: (_) => widget.onCancel(),
      child: Focus(
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
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter ||
              pressedSave) {
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
              width: 240,
              child: TextField(
                controller: _nameC,
                focusNode: _nameFocus,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [_normalizedUppercaseFormatter()],
                decoration: _catalogInlineFieldDecoration(
                  context,
                  'Contraparte',
                ),
                onSubmitted: (_) => _kindFocus.requestFocus(),
              ),
            ),
            _CatalogInlineFieldCell(
              width: 140,
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
              width: 160,
              child: _CatalogPickerButtonField<String>(
                focusNode: _groupFocus,
                label: 'Grupo',
                displayValue: _group,
                dialogTitle: 'Seleccionar grupo',
                initialValue:
                    _kCounterpartyGroupOptions.any(
                      (option) => option.value == _group,
                    )
                    ? _group
                    : null,
                options: _kCounterpartyGroupOptions,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _group = value);
                },
                onSelected: () => _siteFocus.requestFocus(),
              ),
            ),
            _CatalogInlineFieldCell(
              width: 240,
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
              width: 100,
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
    super.key,
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
  final FocusNode _directionFocus = FocusNode();
  final FocusNode _materialFocus = FocusNode();
  final FocusNode _amountFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();
  String? _counterpartyId;
  String? _generalMaterialId;
  String? _commercialMaterialId;
  late String _direction;
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
    _direction = (widget.row['direction'] ?? 'purchase').toString();
    _isActive = (widget.row['price_active'] ?? true) == true;
  }

  @override
  void dispose() {
    _amountC.dispose();
    _notesC.dispose();
    _counterpartyFocus.dispose();
    _directionFocus.dispose();
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

  String _kindLabel() {
    final counterparty = widget.counterparties.firstWhere(
      (row) => (row['id'] ?? '').toString() == _counterpartyId,
      orElse: () => const {},
    );
    final kind = _counterpartyKindLabel(
      (counterparty['kind'] ?? '').toString(),
    );
    return kind.isEmpty ? 'AUTO' : kind;
  }

  void _submit() {
    final parsed = double.tryParse(_amountC.text.trim());
    widget.onSave({
      'counterparty_id': _counterpartyId,
      'general_material_id': _generalMaterialId,
      'commercial_material_id': _commercialMaterialId,
      'direction': _direction,
      'material_label_snapshot': _materialLabel(),
      'final_price': parsed,
      'notes': _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
      'is_active': _isActive,
    });
  }

  void submitFromParent() => _submit();

  void cancelFromParent() => widget.onCancel();

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _kCatalogEditTapRegionGroup,
      onTapOutside: (_) => widget.onCancel(),
      child: Focus(
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
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter ||
              pressedSave) {
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
              width: 220,
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
                  setState(() {
                    _counterpartyId = value;
                    final counterparty = widget.counterparties.firstWhere(
                      (row) => (row['id'] ?? '').toString() == value,
                      orElse: () => const <String, dynamic>{},
                    );
                    _direction = _defaultPriceDirectionForKind(
                      (counterparty['kind'] ?? '').toString(),
                    );
                  });
                },
                onSelected: () => _directionFocus.requestFocus(),
              ),
            ),
            _CatalogInlineFieldCell(
              width: 150,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _kindLabel(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            _CatalogInlineFieldCell(
              width: 220,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _groupLabel(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            _CatalogInlineFieldCell(
              width: 150,
              child: _CatalogPickerButtonField<String>(
                focusNode: _directionFocus,
                label: 'Dirección',
                displayValue: _priceDirectionLabel(_direction),
                dialogTitle: 'Seleccionar dirección',
                initialValue: _direction,
                options: const [
                  _MenudeoPickerOption(value: 'purchase', label: 'COMPRA'),
                  _MenudeoPickerOption(value: 'sale', label: 'VENTA'),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _direction = value);
                },
                onSelected: () => _materialFocus.requestFocus(),
              ),
            ),
            _CatalogInlineFieldCell(
              width: 220,
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
              width: 220,
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
              width: 100,
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
              width: 240,
              child: TextField(
                controller: _notesC,
                focusNode: _notesFocus,
                decoration: _catalogInlineFieldDecoration(context, 'Notas'),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneralMaterialInlineEditRow extends StatefulWidget {
  final Map<String, dynamic> row;
  final VoidCallback onCancel;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _GeneralMaterialInlineEditRow({
    super.key,
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

  void submitFromParent() => _submit();

  void cancelFromParent() => widget.onCancel();

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _kCatalogEditTapRegionGroup,
      onTapOutside: (_) => widget.onCancel(),
      child: Focus(
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
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter ||
              pressedSave) {
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
              width: 120,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _RowChip(
                  label: 'GENERAL',
                  tone: const Color(0xFF8E3F2A),
                ),
              ),
            ),
            _CatalogInlineFieldCell(
              width: 260,
              child: TextField(
                controller: _nameC,
                focusNode: _nameFocus,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [_normalizedUppercaseFormatter()],
                decoration: _catalogInlineFieldDecoration(context, 'Material'),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _notesFocus.requestFocus(),
              ),
            ),
            const _CatalogInlineFieldCell(
              width: 160,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('—', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const _CatalogInlineFieldCell(
              width: 240,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Catalogo base',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            _CatalogInlineFieldCell(
              width: 100,
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
              width: 240,
              child: TextField(
                controller: _notesC,
                focusNode: _notesFocus,
                decoration: _catalogInlineFieldDecoration(context, 'Notas'),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
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
    super.key,
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

  void submitFromParent() => _submit();

  void cancelFromParent() => widget.onCancel();

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _kCatalogEditTapRegionGroup,
      onTapOutside: (_) => widget.onCancel(),
      child: Focus(
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
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter ||
              pressedSave) {
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
              width: 120,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _RowChip(
                  label: 'COMERCIAL',
                  tone: const Color(0xFFE89A5B),
                ),
              ),
            ),
            _CatalogInlineFieldCell(
              width: 260,
              child: TextField(
                controller: _nameC,
                focusNode: _nameFocus,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [_normalizedUppercaseFormatter()],
                decoration: _catalogInlineFieldDecoration(context, 'Material'),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _familyFocus.requestFocus(),
              ),
            ),
            _CatalogInlineFieldCell(
              width: 160,
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
              width: 240,
              child: _CatalogPickerButtonField<String>(
                focusNode: _generalFocus,
                label: 'Relacion',
                displayValue:
                    widget.generalMaterials
                        .firstWhere(
                          (row) =>
                              (row['id'] ?? '').toString() ==
                              _generalMaterialId,
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
              width: 100,
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
              width: 240,
              child: TextField(
                controller: _notesC,
                focusNode: _notesFocus,
                decoration: _catalogInlineFieldDecoration(context, 'Notas'),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenudeoPickerOption<T> {
  final T value;
  final String label;

  const _MenudeoPickerOption({required this.value, required this.label});
}

const TextStyle _kMenudeoMenuTextStyle = TextStyle(
  fontSize: 13.5,
  fontWeight: FontWeight.w800,
  color: Color(0xFF2D2A28),
  letterSpacing: 0.2,
);

Widget _menudeoPopupMenuItemChild({
  required IconData icon,
  required String label,
}) {
  return Row(
    children: [
      Icon(icon, size: 18, color: const Color(0xFF8E3F2A)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label.toUpperCase(),
          style: _kMenudeoMenuTextStyle,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

Widget _menudeoPickerOptionTile({
  required BuildContext context,
  required String label,
  required bool selected,
  required bool highlighted,
  required VoidCallback onTap,
  ValueChanged<bool>? onHover,
  Widget? trailing,
}) {
  final tokens = AreaThemeScope.of(context);
  return InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    onHover: onHover,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: highlighted
            ? tokens.badgeBackground.withValues(alpha: 0.78)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted
              ? tokens.primaryStrong.withValues(alpha: 0.95)
              : Colors.transparent,
          width: 1.15,
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
          ?trailing,
        ],
      ),
    ),
  );
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
    barrierColor: Colors.black.withValues(alpha: 0.28),
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
          return AreaThemeScope(
            tokens: menudeoAreaTokens,
            child: Builder(
              builder: (context) {
                final tokens = AreaThemeScope.of(context);
                return TapRegion(
                  groupId: _kCatalogEditTapRegionGroup,
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
                                  autofocus: true,
                                  decoration: contractGlassFieldDecoration(
                                    context,
                                    hintText: 'Buscar',
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                    ),
                                  ),
                                  onChanged: (value) =>
                                      setLocalState(() => q = value),
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
                                        color: tokens.primaryStrong,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Expanded(
                                child: filtered.isEmpty
                                    ? const Center(
                                        child: Text('Sin resultados'),
                                      )
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
                                              if (!hasFocus &&
                                                  focusedIndex == i) {
                                                setLocalState(
                                                  () => focusedIndex = null,
                                                );
                                              } else if (hasFocus) {
                                                setLocalState(
                                                  () => focusedIndex = i,
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
                                                      LogicalKeyboardKey
                                                          .arrowDown &&
                                                  i <
                                                      itemFocusNodes.length -
                                                          1) {
                                                itemFocusNodes[i + 1]
                                                    .requestFocus();
                                                return KeyEventResult.handled;
                                              }
                                              if (event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .enter ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .numpadEnter ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .space) {
                                                Navigator.of(
                                                  dialogContext,
                                                ).pop(option.value);
                                                return KeyEventResult.handled;
                                              }
                                              return KeyEventResult.ignored;
                                            },
                                            child: _menudeoPickerOptionTile(
                                              context: context,
                                              label: option.label,
                                              selected: selected,
                                              highlighted: highlighted,
                                              onTap: () => Navigator.of(
                                                dialogContext,
                                              ).pop(option.value),
                                              onHover: (value) {
                                                if (value) {
                                                  setLocalState(
                                                    () => focusedIndex = i,
                                                  );
                                                }
                                              },
                                              trailing: selected
                                                  ? Icon(
                                                      Icons.check_rounded,
                                                      size: 18,
                                                      color:
                                                          tokens.primaryStrong,
                                                    )
                                                  : null,
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
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      final searchC = TextEditingController();
      final searchFocus = FocusNode();
      final itemFocusNodes = <FocusNode>[];
      final selected = <T>{...initialValues};
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
          return AreaThemeScope(
            tokens: menudeoAreaTokens,
            child: Builder(
              builder: (context) {
                final tokens = AreaThemeScope.of(context);
                return TapRegion(
                  groupId: _kCatalogEditTapRegionGroup,
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
                                  autofocus: true,
                                  decoration: contractGlassFieldDecoration(
                                    context,
                                    hintText: 'Buscar',
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                    ),
                                  ),
                                  onChanged: (value) =>
                                      setLocalState(() => q = value),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: filtered.isEmpty
                                    ? const Center(
                                        child: Text('Sin resultados'),
                                      )
                                    : ListView.builder(
                                        itemCount: filtered.length,
                                        itemBuilder: (_, i) {
                                          final option = filtered[i];
                                          final checked = selected.contains(
                                            option.value,
                                          );
                                          return Focus(
                                            focusNode: itemFocusNodes[i],
                                            onFocusChange: (hasFocus) {
                                              if (!hasFocus &&
                                                  focusedIndex == i) {
                                                setLocalState(() {
                                                  focusedIndex = null;
                                                });
                                              } else if (hasFocus) {
                                                setLocalState(
                                                  () => focusedIndex = i,
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
                                                      LogicalKeyboardKey
                                                          .arrowDown &&
                                                  i <
                                                      itemFocusNodes.length -
                                                          1) {
                                                itemFocusNodes[i + 1]
                                                    .requestFocus();
                                                return KeyEventResult.handled;
                                              }
                                              if (event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .enter ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .numpadEnter ||
                                                  event.logicalKey ==
                                                      LogicalKeyboardKey
                                                          .space) {
                                                setLocalState(() {
                                                  if (checked) {
                                                    selected.remove(
                                                      option.value,
                                                    );
                                                  } else {
                                                    selected.add(option.value);
                                                  }
                                                });
                                                return KeyEventResult.handled;
                                              }
                                              return KeyEventResult.ignored;
                                            },
                                            child: _menudeoPickerOptionTile(
                                              context: context,
                                              label: option.label,
                                              selected: checked,
                                              highlighted: focusedIndex == i,
                                              onTap: () {
                                                setLocalState(() {
                                                  if (checked) {
                                                    selected.remove(
                                                      option.value,
                                                    );
                                                  } else {
                                                    selected.add(option.value);
                                                  }
                                                });
                                              },
                                              onHover: (value) {
                                                setLocalState(() {
                                                  focusedIndex = value
                                                      ? i
                                                      : null;
                                                });
                                              },
                                              trailing: Checkbox(
                                                value: checked,
                                                onChanged: (value) {
                                                  setLocalState(() {
                                                    if (value == true) {
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
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                visualDensity:
                                                    VisualDensity.compact,
                                                activeColor:
                                                    tokens.primaryStrong,
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
                                    style: contractSecondaryButtonStyle(
                                      context,
                                    ),
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(<T>{}),
                                    child: Text(
                                      'Limpiar',
                                      style: TextStyle(
                                        color: tokens.primaryStrong,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: contractPrimaryButtonStyle(context),
                                    onPressed: () => Navigator.of(
                                      dialogContext,
                                    ).pop(selected),
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
            ),
          );
        },
      );
    },
  );
}

class _CatalogPickerButtonField<T> extends StatefulWidget {
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
    super.key,
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

  @override
  State<_CatalogPickerButtonField<T>> createState() =>
      _CatalogPickerButtonFieldState<T>();
}

class _CatalogPickerButtonFieldState<T>
    extends State<_CatalogPickerButtonField<T>> {
  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _CatalogPickerButtonField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    oldWidget.focusNode?.removeListener(_handleFocusChange);
    widget.focusNode?.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_handleFocusChange);
    super.dispose();
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = await _showMenudeoSearchablePickerDialog<T>(
      context,
      title: widget.dialogTitle,
      options: widget.options,
      initialValue: widget.initialValue,
      allowClear: widget.allowClear,
    );
    widget.onChanged(selected);
    if (selected != null) {
      widget.onSelected?.call();
    }
  }

  Widget _buildField(BuildContext context, {required bool focused}) {
    final tokens = AreaThemeScope.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => unawaited(_openPicker(context)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: focused
                ? tokens.primaryStrong
                : tokens.border.withValues(alpha: 0.9),
            width: focused ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                widget.displayValue.isEmpty
                    ? widget.label
                    : widget.displayValue,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: widget.displayValue.isEmpty
                      ? const Color(0xFF7D746F)
                      : const Color(0xFF2D2A28),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_drop_down_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            widget.onMovePrev != null) {
          widget.onMovePrev!.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
            widget.onMoveNext != null) {
          widget.onMoveNext!.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
            widget.onMoveDown != null) {
          widget.onMoveDown!.call();
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
      child: _buildField(context, focused: widget.focusNode?.hasFocus ?? false),
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
                                          ? menudeoAreaTokens.primary
                                          : menudeoAreaTokens.badgeBackground,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: column.active
                                            ? menudeoAreaTokens.primaryStrong
                                            : menudeoAreaTokens.border,
                                      ),
                                    ),
                                    child: Icon(
                                      column.active
                                          ? Icons.filter_alt
                                          : Icons.filter_alt_outlined,
                                      size: 15,
                                      color: column.active
                                          ? Colors.white
                                          : menudeoAreaTokens.badgeText,
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
  final ScrollController? controller;
  final Key? viewportKey;

  const _CatalogTableList({
    required this.emptyLabel,
    required this.contentWidth,
    required this.rows,
    this.controller,
    this.viewportKey,
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
      items: [
        for (final item in widget.menuItems)
          PopupMenuItem<_RowMenuAction>(
            value: item,
            child: _menudeoPopupMenuItemChild(
              icon: item.icon,
              label: item.label,
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
                  color: tokens.border.withValues(alpha: 0.90),
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
                                    color: menudeoAreaTokens.surfaceTint
                                        .withValues(alpha: 0.98),
                                    elevation: 8,
                                    shadowColor: Colors.black.withValues(
                                      alpha: 0.12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                    onOpened: widget.onSecondarySelection,
                                    onSelected: (item) => item.onTap(),
                                    itemBuilder: (context) => [
                                      for (final item in widget.menuItems)
                                        PopupMenuItem<_RowMenuAction>(
                                          value: item,
                                          child: _menudeoPopupMenuItemChild(
                                            icon: item.icon,
                                            label: item.label,
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

class _CatalogSidePanel extends StatelessWidget {
  final ValueChanged<String> onNavigate;

  const _CatalogSidePanel({required this.onNavigate});

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
              const _CatalogSectionHeader(label: 'MENU'),
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
                    _CatalogPanelItem(
                      icon: Icons.receipt_long_rounded,
                      title: 'Compras',
                      subtitle: 'Tickets virtuales de compra',
                      onTapSync: () => onNavigate('Tickets de menudeo'),
                    ),
                    const SizedBox(height: 8),
                    _CatalogPanelItem(
                      icon: Icons.point_of_sale_rounded,
                      title: 'Ventas',
                      subtitle: 'Tickets virtuales de venta',
                      onTapSync: () => onNavigate('Ventas menudeo'),
                    ),
                    const SizedBox(height: 8),
                    _CatalogPanelItem(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Depósitos y gastos',
                      subtitle: 'Vouchers de caja y egresos',
                      onTapSync: () => onNavigate('Depósitos y gastos'),
                    ),
                    const SizedBox(height: 8),
                    _CatalogPanelItem(
                      icon: Icons.auto_graph_rounded,
                      title: 'Ajuste de precios',
                      subtitle: 'Cambios e historial',
                      onTapSync: () => onNavigate('Ajuste de precios'),
                    ),
                    const SizedBox(height: 8),
                    _CatalogPanelItem(
                      icon: Icons.price_check_rounded,
                      title: 'Catálogo',
                      subtitle: 'Materiales, grupos y precios',
                      isActive: true,
                      onTapSync: () => onNavigate('Catálogo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _CatalogSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              _CatalogPanelItem(
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

class _CatalogSectionHeader extends StatelessWidget {
  final String label;

  const _CatalogSectionHeader({required this.label});

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

class _CatalogPanelItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isActive;
  final bool isAccent;
  final VoidCallback? onTapSync;

  const _CatalogPanelItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.isActive = false,
    this.isAccent = false,
    this.onTapSync,
  });

  @override
  State<_CatalogPanelItem> createState() => _CatalogPanelItemState();
}

class _CatalogPanelItemState extends State<_CatalogPanelItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final active = widget.isActive;
    final hasSubtitle =
        widget.subtitle != null && widget.subtitle!.trim().isNotEmpty;
    final border = widget.isAccent
        ? Colors.white.withValues(alpha: 0.72)
        : active
        ? tokens.primaryStrong.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: _hovered ? 0.62 : 0.58);
    final shadowColor = widget.isAccent
        ? kMenudeoPanelShadow.withValues(alpha: 0.24)
        : active
        ? kMenudeoPanelShadow.withValues(alpha: 0.18)
        : kMenudeoPanelShadow.withValues(alpha: _hovered ? 0.14 : 0.12);

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
                    ? kMenudeoPanelAccentGradient
                    : active
                    ? kMenudeoPanelHighlightGradient
                    : kMenudeoPanelGradient,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
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

class _CatalogHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _CatalogHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_CatalogHeaderButton> createState() => _CatalogHeaderButtonState();
}

class _CatalogHeaderButtonState extends State<_CatalogHeaderButton> {
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
                    offset: const Offset(0, 0),
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
