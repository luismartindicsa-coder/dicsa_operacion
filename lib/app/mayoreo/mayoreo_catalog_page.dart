import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/editable_hover_capsule.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import '../services/inventory_movements_grid.dart';
import 'mayoreo_accounts_page.dart';
import 'mayoreo_dashboard_preview_page.dart';
import 'mayoreo_data_store.dart';
import 'mayoreo_el_palomar_page.dart';
import 'mayoreo_price_adjustments_page.dart';
import 'mayoreo_sales_report_page.dart';
import 'mayoreo_theme.dart';

const double _kCatalogActionsW = 86;
const double _kCompanyNameW = 420;
const double _kCompanyContactW = 220;
const double _kCompanyStatusW = 120;
const double _kCompanyNotesW = 530;
const double _kCompanyContentW =
    _kCompanyNameW + _kCompanyContactW + _kCompanyStatusW + _kCompanyNotesW;

const double _kMaterialLevelW = 220;
const double _kMaterialNameW = 220;
const double _kMaterialFamilyW = 220;
const double _kMaterialRelationW = 220;
const double _kMaterialStatusW = 100;
const double _kMaterialNotesW = 220;
const double _kMaterialContentW =
    _kMaterialLevelW +
    _kMaterialNameW +
    _kMaterialFamilyW +
    _kMaterialRelationW +
    _kMaterialStatusW +
    _kMaterialNotesW;

const double _kPriceCompanyW = 280;
const double _kPriceMaterialW = 280;
const double _kPriceAmountW = 180;
const double _kPriceStatusW = 100;
const double _kPriceNotesW = 260;
const double _kPriceContentW =
    _kPriceCompanyW +
    _kPriceMaterialW +
    _kPriceAmountW +
    _kPriceStatusW +
    _kPriceNotesW;
const List<String> _kMayoreoGeneralCategories = <String>[
  'CARTON',
  'CHATARRA',
  'METAL',
  'PAPEL',
  'PLASTICO',
  'MADERA',
  'OTRO',
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
  final normalized = _stripAccents(raw).toUpperCase();
  return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _codeFromName(String raw) {
  return _normalizeName(raw)
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

String _money(double value) => '\$${value.toStringAsFixed(2)}';

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

class MayoreoCatalogPage extends StatefulWidget {
  final bool instantOpen;

  const MayoreoCatalogPage({super.key, this.instantOpen = false});

  @override
  State<MayoreoCatalogPage> createState() => _MayoreoCatalogPageState();
}

class _MayoreoCatalogPageState extends State<MayoreoCatalogPage> {
  bool _canReturnToDirection = false;
  bool _menuOpen = false;
  int _activeTabIndex = 0;
  String? _editingRowKey;
  bool _multiEditMode = false;
  String? _selectedRowKey;
  String? _selectionAnchorRowKey;
  final Set<String> _bulkSelectedRowKeys = <String>{};
  final FocusNode _gridRowsFocusNode = FocusNode(
    debugLabel: 'mayoreo_catalog_grid',
  );
  bool _dragSelectionActive = false;
  List<String> _dragSelectionKeys = const <String>[];
  String? _dragSelectionAnchorKey;

  final TextEditingController _companyNameC = TextEditingController();
  final TextEditingController _companyContactC = TextEditingController();
  final TextEditingController _companyNotesC = TextEditingController();
  final FocusNode _companyNameFocus = FocusNode();
  final FocusNode _companyContactFocus = FocusNode();
  final FocusNode _companyNotesFocus = FocusNode();

  final TextEditingController _materialNameC = TextEditingController();
  final TextEditingController _materialNotesC = TextEditingController();
  final FocusNode _materialLevelFocus = FocusNode();
  final FocusNode _materialNameFocus = FocusNode();
  final FocusNode _materialFamilyFocus = FocusNode();
  final FocusNode _materialRelationFocus = FocusNode();
  final FocusNode _materialNotesFocus = FocusNode();
  String _materialLevel = 'GENERAL';
  String _materialFamily = 'METAL';
  String? _materialGeneralMaterialId;

  String? _priceCompanyId;
  String? _priceMaterialId;
  final TextEditingController _priceAmountC = TextEditingController();
  final TextEditingController _priceNotesC = TextEditingController();
  final FocusNode _priceCompanyFocus = FocusNode();
  final FocusNode _priceMaterialFocus = FocusNode();
  final FocusNode _priceAmountFocus = FocusNode();
  final FocusNode _priceNotesFocus = FocusNode();

  final Map<String, GlobalKey<_CompanyInlineEditRowState>> _companyEditRowKeys =
      <String, GlobalKey<_CompanyInlineEditRowState>>{};
  final Map<String, GlobalKey<_MaterialInlineEditRowState>>
  _materialEditRowKeys = <String, GlobalKey<_MaterialInlineEditRowState>>{};
  final Map<String, GlobalKey<_PriceInlineEditRowState>> _priceEditRowKeys =
      <String, GlobalKey<_PriceInlineEditRowState>>{};

  bool? _companyActiveFilter;
  Set<String> _companyNameFilters = <String>{};
  Set<String> _companyContactFilters = <String>{};
  Set<String> _materialLevelFilters = <String>{};
  Set<String> _materialNameFilters = <String>{};
  Set<String> _materialFamilyFilters = <String>{};
  Set<String> _materialRelationFilters = <String>{};
  bool? _materialActiveFilter;
  String? _priceCompanyFilterId;
  String? _priceMaterialFilterId;
  bool? _priceActiveFilter;

  late List<_MayoreoCompany> _companies;
  late List<_MayoreoMaterial> _materials;
  late List<_MayoreoPrice> _prices;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    _companies = <_MayoreoCompany>[];
    _materials = <_MayoreoMaterial>[];
    _prices = <_MayoreoPrice>[];
    unawaited(_loadCatalogSnapshot());
  }

  Future<void> _loadCatalogSnapshot() async {
    final snapshot = await MayoreoDataStore.loadCatalogSnapshot();
    if (!mounted) return;
    setState(() {
      _companies = snapshot.companies
          .map(
            (row) => _MayoreoCompany(
              id: row.id,
              code: row.code,
              name: row.name,
              contact: row.contact,
              active: row.active,
              notes: row.notes,
            ),
          )
          .toList(growable: false);
      _materials = snapshot.materials
          .map(
            (row) => _MayoreoMaterial(
              id: row.id,
              code: row.code,
              level: row.level,
              name: row.name,
              unit: row.unit,
              category: row.category,
              family: row.family,
              generalMaterialId: row.generalMaterialId,
              active: row.active,
              notes: row.notes,
            ),
          )
          .toList(growable: false);
      _prices = snapshot.prices
          .map(
            (row) => _MayoreoPrice(
              id: row.id,
              companyId: row.companyId,
              materialId: row.materialId,
              amount: row.amount,
              active: row.active,
              notes: row.notes,
              updatedAt: row.updatedAt,
            ),
          )
          .toList(growable: false);
    });
  }

  Future<void> _persistCatalogSnapshot() async {
    final snapshot = MayoreoCatalogSnapshot(
      companies: _companies
          .map(
            (row) => MayoreoCatalogCompanyRecord(
              id: row.id,
              code: row.code,
              name: row.name,
              contact: row.contact,
              active: row.active,
              notes: row.notes,
            ),
          )
          .toList(growable: false),
      materials: _materials
          .map(
            (row) => MayoreoCatalogMaterialRecord(
              id: row.id,
              code: row.code,
              level: row.level,
              name: row.name,
              unit: row.unit,
              category: row.category,
              family: row.family,
              generalMaterialId: row.generalMaterialId,
              active: row.active,
              notes: row.notes,
            ),
          )
          .toList(growable: false),
      prices: _prices
          .map(
            (row) => MayoreoCatalogPriceRecord(
              id: row.id,
              companyId: row.companyId,
              materialId: row.materialId,
              amount: row.amount,
              active: row.active,
              notes: row.notes,
              updatedAt: row.updatedAt,
            ),
          )
          .toList(growable: false),
    );
    await MayoreoDataStore.saveCatalogSnapshot(snapshot);
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
    });
  }

  @override
  void dispose() {
    _gridRowsFocusNode.dispose();
    _companyNameC.dispose();
    _companyContactC.dispose();
    _companyNotesC.dispose();
    _companyNameFocus.dispose();
    _companyContactFocus.dispose();
    _companyNotesFocus.dispose();
    _materialNameC.dispose();
    _materialNotesC.dispose();
    _materialLevelFocus.dispose();
    _materialNameFocus.dispose();
    _materialFamilyFocus.dispose();
    _materialRelationFocus.dispose();
    _materialNotesFocus.dispose();
    _priceAmountC.dispose();
    _priceNotesC.dispose();
    _priceCompanyFocus.dispose();
    _priceMaterialFocus.dispose();
    _priceAmountFocus.dispose();
    _priceNotesFocus.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const MayoreoDashboardPreviewPage(instantOpen: true)),
    );
  }

  Future<void> _openPriceAdjustments() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const MayoreoPriceAdjustmentsPage(instantOpen: true)),
    );
  }

  Future<void> _openSalesReports() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const MayoreoSalesReportPage(instantOpen: true)),
    );
  }

  Future<void> _openAccounts() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const MayoreoAccountsPage(instantOpen: true)),
    );
  }

  Future<void> _openElPalomar() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const MayoreoElPalomarPage(instantOpen: true)));
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  void _showStub(String label) {
    _toast('$label quedará conectado en la siguiente fase de Mayoreo.');
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Dirección':
        unawaited(_openDirectionDashboard());
        return;
      case 'Dashboard Mayoreo':
        unawaited(_openDashboard());
        return;
      case 'Ventas Mayoreo':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openSalesReports());
        return;
      case 'Cuentas':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openAccounts());
        return;
      case 'Cuenta El Palomar':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openElPalomar());
        return;
      case 'Catálogo':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      case 'Ajuste de precios':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openPriceAdjustments());
        return;
      default:
        if (_menuOpen) setState(() => _menuOpen = false);
        _showStub(label);
    }
  }

  void _resetCompanyDraft() {
    _companyNameC.clear();
    _companyContactC.clear();
    _companyNotesC.clear();
  }

  void _resetMaterialDraft() {
    _materialNameC.clear();
    _materialNotesC.clear();
    _materialLevel = 'GENERAL';
    _materialFamily = 'METAL';
    _materialGeneralMaterialId = null;
  }

  void _resetPriceDraft() {
    _priceCompanyId = null;
    _priceMaterialId = null;
    _priceAmountC.clear();
    _priceNotesC.clear();
  }

  void _saveCompany() {
    final name = _normalizeName(_companyNameC.text);
    final code = _codeFromName(name);
    final contact = _normalizeName(_companyContactC.text);
    if (name.isEmpty) {
      _toast('El nombre de la empresa es obligatorio');
      return;
    }
    setState(() {
      final company = _MayoreoCompany(
        id: 'co_${DateTime.now().microsecondsSinceEpoch}',
        code: code,
        name: name,
        contact: contact,
        notes: _companyNotesC.text.trim(),
      );
      _companies = [company, ..._companies];
      _selectedRowKey = 'co:${company.id}';
      _resetCompanyDraft();
    });
    unawaited(_persistCatalogSnapshot());
    _companyNameFocus.requestFocus();
  }

  void _saveMaterial() {
    final name = _normalizeName(_materialNameC.text);
    final code = _codeFromName(name);
    if (name.isEmpty) {
      _toast('El nombre del material es obligatorio');
      return;
    }
    if (_materialLevel == 'COMERCIAL' && _materialGeneralMaterialId == null) {
      _toast('Selecciona el material general de relación');
      return;
    }
    setState(() {
      final material = _MayoreoMaterial(
        id: 'ma_${DateTime.now().microsecondsSinceEpoch}',
        code: code,
        level: _materialLevel,
        name: name,
        unit: 'KG',
        category: _materialFamily,
        family: _materialLevel == 'GENERAL' ? null : _materialFamily,
        generalMaterialId: _materialLevel == 'GENERAL'
            ? null
            : _materialGeneralMaterialId,
        notes: _materialNotesC.text.trim(),
      );
      _materials = [material, ..._materials];
      _selectedRowKey = 'ma:${material.id}';
      _resetMaterialDraft();
    });
    unawaited(_persistCatalogSnapshot());
    _materialNameFocus.requestFocus();
  }

  void _savePrice() {
    final companyId = _priceCompanyId;
    final materialId = _priceMaterialId;
    final amount = double.tryParse(_priceAmountC.text.replaceAll(',', ''));
    if (companyId == null || materialId == null || amount == null) {
      _toast('Empresa, material y precio son obligatorios');
      return;
    }
    setState(() {
      final price = _MayoreoPrice(
        id: 'pr_${DateTime.now().microsecondsSinceEpoch}',
        companyId: companyId,
        materialId: materialId,
        amount: amount,
        notes: _priceNotesC.text.trim(),
        updatedAt: DateTime.now(),
      );
      _prices = [price, ..._prices];
      _selectedRowKey = 'pr:${price.id}';
      _resetPriceDraft();
    });
    unawaited(_persistCatalogSnapshot());
    _priceCompanyFocus.requestFocus();
  }

  Future<void> _exportCurrentTab() async {
    final csv = switch (_activeTabIndex) {
      0 => _companiesCsv(),
      1 => _materialsCsv(),
      _ => _pricesCsv(),
    };
    final fileName = switch (_activeTabIndex) {
      0 => 'mayoreo_empresas.csv',
      1 => 'mayoreo_materiales.csv',
      _ => 'mayoreo_precios.csv',
    };
    final path = await saveCsvFile(fileName: fileName, content: csv);
    if (!mounted) return;
    _toast(path == null ? 'Exportación cancelada' : 'CSV guardado');
  }

  String _companiesCsv() {
    final rows = [
      'empresa,clave,contacto,estatus,notas',
      for (final row in _companies)
        [
          row.name,
          row.code,
          row.contact,
          row.active ? 'ACTIVO' : 'INACTIVO',
          row.notes,
        ].map(_csvCell).join(','),
    ];
    return rows.join('\n');
  }

  String _materialsCsv() {
    final rows = [
      'nivel,material,clave,familia,relacion,estatus,notas',
      for (final row in _materials)
        [
          row.level,
          row.name,
          row.code,
          row.level == 'GENERAL' ? '' : (row.family ?? row.category),
          row.level == 'GENERAL'
              ? 'CATALOGO BASE'
              : _materialRelationLabel(row.generalMaterialId),
          row.active ? 'ACTIVO' : 'INACTIVO',
          row.notes,
        ].map(_csvCell).join(','),
    ];
    return rows.join('\n');
  }

  String _pricesCsv() {
    final rows = [
      'empresa,material,precio,estatus,notas',
      for (final row in _prices)
        [
          _companyName(row.companyId),
          _materialName(row.materialId),
          row.amount.toStringAsFixed(2),
          row.active ? 'ACTIVO' : 'INACTIVO',
          row.notes,
        ].map(_csvCell).join(','),
    ];
    return rows.join('\n');
  }

  String _csvCell(String value) =>
      '"${value.replaceAll('"', '""').replaceAll('\n', ' ')}"';

  String _companyName(String id) {
    return _companies
        .firstWhere(
          (row) => row.id == id,
          orElse: () => const _MayoreoCompany.empty(),
        )
        .name;
  }

  String _materialName(String id) {
    return _materials
        .firstWhere(
          (row) => row.id == id,
          orElse: () => const _MayoreoMaterial.empty(),
        )
        .name;
  }

  String _materialRelationLabel(String? id) {
    if (id == null) return 'Catalogo base';
    return _materials
        .firstWhere(
          (row) => row.id == id,
          orElse: () => const _MayoreoMaterial.empty(),
        )
        .name;
  }

  List<_MayoreoMaterial> get _generalMaterials =>
      _materials.where((row) => row.level == 'GENERAL').toList(growable: false);

  List<_MayoreoMaterial> get _commercialMaterials => _materials
      .where((row) => row.level == 'COMERCIAL')
      .toList(growable: false);

  List<_MayoreoCompany> get _visibleCompanies {
    return _companies
        .where((row) {
          if (_companyNameFilters.isNotEmpty &&
              !_companyNameFilters.contains(row.name)) {
            return false;
          }
          if (_companyContactFilters.isNotEmpty &&
              !_companyContactFilters.contains(row.contact)) {
            return false;
          }
          if (_companyActiveFilter != null &&
              row.active != _companyActiveFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<_MayoreoMaterial> get _visibleMaterials {
    return _materials
        .where((row) {
          if (_materialLevelFilters.isNotEmpty &&
              !_materialLevelFilters.contains(row.level)) {
            return false;
          }
          if (_materialNameFilters.isNotEmpty &&
              !_materialNameFilters.contains(row.name)) {
            return false;
          }
          final familyLabel = row.level == 'GENERAL'
              ? '—'
              : (row.family ?? row.category);
          if (_materialFamilyFilters.isNotEmpty &&
              !_materialFamilyFilters.contains(familyLabel)) {
            return false;
          }
          final relationLabel = row.level == 'GENERAL'
              ? 'CATALOGO BASE'
              : _materialRelationLabel(row.generalMaterialId);
          if (_materialRelationFilters.isNotEmpty &&
              !_materialRelationFilters.contains(relationLabel)) {
            return false;
          }
          if (_materialActiveFilter != null &&
              row.active != _materialActiveFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<_MayoreoPrice> get _visiblePrices {
    return _prices
        .where((row) {
          if (_priceCompanyFilterId != null &&
              row.companyId != _priceCompanyFilterId) {
            return false;
          }
          if (_priceMaterialFilterId != null &&
              row.materialId != _priceMaterialFilterId) {
            return false;
          }
          if (_priceActiveFilter != null && row.active != _priceActiveFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  void _requestActiveInsertFocus() {
    switch (_activeTabIndex) {
      case 0:
        _companyNameFocus.requestFocus();
        break;
      case 1:
        _materialNameFocus.requestFocus();
        break;
      default:
        _priceCompanyFocus.requestFocus();
        break;
    }
  }

  void _focusGridRows() {
    if (_currentRowKeys().isEmpty) return;
    _gridRowsFocusNode.requestFocus();
    if (_selectedRowKey != null) return;
    setState(() => _setSingleSelection(_currentRowKeys().first));
  }

  KeyEventResult _handleInsertTextNavigation({
    required KeyEvent event,
    required TextEditingController controller,
    FocusNode? previous,
    FocusNode? next,
    VoidCallback? onDown,
    VoidCallback? onEnter,
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
    if ((event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        onEnter != null) {
      onEnter();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _pickCompanyActiveFilter() async {
    final value = await _showMayoreoSingleSelectDialog<bool?>(
      context,
      title: 'Filtrar estatus de empresas',
      initialValue: _companyActiveFilter,
      allowClear: true,
      options: const [
        _MayoreoPickerOption(value: true, label: 'ACTIVO'),
        _MayoreoPickerOption(value: false, label: 'INACTIVO'),
      ],
    );
    if (!mounted) return;
    setState(() => _companyActiveFilter = value);
  }

  Future<void> _pickCompanyNameFilter() async {
    final selected = await _showMayoreoMultiSelectDialog<String>(
      context,
      title: 'Filtrar empresa',
      initialValues: _companyNameFilters,
      options: _companies
          .map((row) => _MayoreoPickerOption(value: row.name, label: row.name))
          .toList(growable: false),
    );
    if (!mounted || selected == null) return;
    setState(() => _companyNameFilters = selected);
  }

  Future<void> _pickCompanyContactFilter() async {
    final selected = await _showMayoreoMultiSelectDialog<String>(
      context,
      title: 'Filtrar contacto',
      initialValues: _companyContactFilters,
      options: _companies
          .map(
            (row) =>
                _MayoreoPickerOption(value: row.contact, label: row.contact),
          )
          .toList(growable: false),
    );
    if (!mounted || selected == null) return;
    setState(() => _companyContactFilters = selected);
  }

  Future<void> _pickMaterialUnitFilter() async {
    final selected = await _showMayoreoMultiSelectDialog<String>(
      context,
      title: 'Filtrar nivel',
      initialValues: _materialLevelFilters,
      options: const [
        _MayoreoPickerOption(value: 'GENERAL', label: 'GENERAL'),
        _MayoreoPickerOption(value: 'COMERCIAL', label: 'COMERCIAL'),
      ],
    );
    if (!mounted || selected == null) return;
    setState(() => _materialLevelFilters = selected);
  }

  Future<void> _pickMaterialNameFilter() async {
    final selected = await _showMayoreoMultiSelectDialog<String>(
      context,
      title: 'Filtrar material',
      initialValues: _materialNameFilters,
      options: _materials
          .map((row) => _MayoreoPickerOption(value: row.name, label: row.name))
          .toList(growable: false),
    );
    if (!mounted || selected == null) return;
    setState(() => _materialNameFilters = selected);
  }

  Future<void> _pickMaterialCategoryFilter() async {
    final selected = await _showMayoreoMultiSelectDialog<String>(
      context,
      title: 'Filtrar familia',
      initialValues: _materialFamilyFilters,
      options: _kMayoreoGeneralCategories
          .map((family) => _MayoreoPickerOption(value: family, label: family))
          .toList(growable: false),
    );
    if (!mounted || selected == null) return;
    setState(() => _materialFamilyFilters = selected);
  }

  Future<void> _pickMaterialRelationFilter() async {
    final selected = await _showMayoreoMultiSelectDialog<String>(
      context,
      title: 'Filtrar relación',
      initialValues: _materialRelationFilters,
      options: [
        const _MayoreoPickerOption(
          value: 'CATALOGO BASE',
          label: 'CATALOGO BASE',
        ),
        ..._generalMaterials.map(
          (row) => _MayoreoPickerOption(value: row.name, label: row.name),
        ),
      ],
    );
    if (!mounted || selected == null) return;
    setState(() => _materialRelationFilters = selected);
  }

  Future<void> _pickMaterialActiveFilter() async {
    final value = await _showMayoreoSingleSelectDialog<bool?>(
      context,
      title: 'Filtrar estatus de materiales',
      initialValue: _materialActiveFilter,
      allowClear: true,
      options: const [
        _MayoreoPickerOption(value: true, label: 'ACTIVO'),
        _MayoreoPickerOption(value: false, label: 'INACTIVO'),
      ],
    );
    if (!mounted) return;
    setState(() => _materialActiveFilter = value);
  }

  Future<void> _pickPriceCompanyFilter() async {
    final value = await _showMayoreoSingleSelectDialog<String?>(
      context,
      title: 'Filtrar empresa',
      initialValue: _priceCompanyFilterId,
      allowClear: true,
      options: _companies
          .map(
            (row) =>
                _MayoreoPickerOption<String?>(value: row.id, label: row.name),
          )
          .toList(growable: false),
    );
    if (!mounted) return;
    setState(() => _priceCompanyFilterId = value);
  }

  Future<void> _pickPriceMaterialFilter() async {
    final value = await _showMayoreoSingleSelectDialog<String?>(
      context,
      title: 'Filtrar material',
      initialValue: _priceMaterialFilterId,
      allowClear: true,
      options: _commercialMaterials
          .map(
            (row) =>
                _MayoreoPickerOption<String?>(value: row.id, label: row.name),
          )
          .toList(growable: false),
    );
    if (!mounted) return;
    setState(() => _priceMaterialFilterId = value);
  }

  Future<void> _pickPriceActiveFilter() async {
    final value = await _showMayoreoSingleSelectDialog<bool?>(
      context,
      title: 'Filtrar estatus de precios',
      initialValue: _priceActiveFilter,
      allowClear: true,
      options: const [
        _MayoreoPickerOption(value: true, label: 'ACTIVO'),
        _MayoreoPickerOption(value: false, label: 'INACTIVO'),
      ],
    );
    if (!mounted) return;
    setState(() => _priceActiveFilter = value);
  }

  void _toggleCompanyActive(_MayoreoCompany row) {
    setState(() {
      _companies = _companies
          .map(
            (item) =>
                item.id == row.id ? item.copyWith(active: !item.active) : item,
          )
          .toList(growable: false);
    });
    unawaited(_persistCatalogSnapshot());
  }

  void _toggleMaterialActive(_MayoreoMaterial row) {
    setState(() {
      _materials = _materials
          .map(
            (item) =>
                item.id == row.id ? item.copyWith(active: !item.active) : item,
          )
          .toList(growable: false);
    });
    unawaited(_persistCatalogSnapshot());
  }

  void _togglePriceActive(_MayoreoPrice row) {
    setState(() {
      _prices = _prices
          .map(
            (item) =>
                item.id == row.id ? item.copyWith(active: !item.active) : item,
          )
          .toList(growable: false);
    });
    unawaited(_persistCatalogSnapshot());
  }

  void _toggleSelectedActive() {
    if (_bulkSelectedRowKeys.isEmpty) return;
    final keys = Set<String>.from(_bulkSelectedRowKeys);
    setState(() {
      switch (_activeTabIndex) {
        case 0:
          _companies = _companies
              .map(
                (row) => keys.contains('co:${row.id}')
                    ? row.copyWith(active: !row.active)
                    : row,
              )
              .toList(growable: false);
          break;
        case 1:
          _materials = _materials
              .map(
                (row) => keys.contains('ma:${row.id}')
                    ? row.copyWith(active: !row.active)
                    : row,
              )
              .toList(growable: false);
          break;
        default:
          _prices = _prices
              .map(
                (row) => keys.contains('pr:${row.id}')
                    ? row.copyWith(active: !row.active)
                    : row,
              )
              .toList(growable: false);
      }
    });
    unawaited(_persistCatalogSnapshot());
  }

  void _deleteCompany(_MayoreoCompany row) {
    final inUse = _prices.any((price) => price.companyId == row.id);
    if (inUse) {
      _toast('No puedes eliminar una empresa con precios activos');
      return;
    }
    setState(() {
      _companies = _companies.where((item) => item.id != row.id).toList();
      _removeSelectionKey('co:${row.id}');
    });
    unawaited(_persistCatalogSnapshot());
  }

  void _deleteMaterial(_MayoreoMaterial row) {
    final inUse = _prices.any((price) => price.materialId == row.id);
    if (inUse) {
      _toast('No puedes eliminar un material con precios activos');
      return;
    }
    setState(() {
      _materials = _materials.where((item) => item.id != row.id).toList();
      _removeSelectionKey('ma:${row.id}');
    });
    unawaited(_persistCatalogSnapshot());
  }

  void _deletePrice(_MayoreoPrice row) {
    setState(() {
      _prices = _prices.where((item) => item.id != row.id).toList();
      _removeSelectionKey('pr:${row.id}');
    });
    unawaited(_persistCatalogSnapshot());
  }

  List<String> _currentRowKeys() {
    switch (_activeTabIndex) {
      case 0:
        return _companies
            .map((item) => 'co:${item.id}')
            .toList(growable: false);
      case 1:
        return _materials
            .map((item) => 'ma:${item.id}')
            .toList(growable: false);
      default:
        return _prices.map((item) => 'pr:${item.id}').toList(growable: false);
    }
  }

  bool _isCtrlOrCmdPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
  }

  bool _isShiftPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
  }

  bool _isEditableTextFocused() {
    final widget = FocusManager.instance.primaryFocus?.context?.widget;
    return widget is EditableText;
  }

  bool get _gridHasPrimaryKeyboardFocus => _gridRowsFocusNode.hasPrimaryFocus;

  void _setSingleSelection(String rowKey) {
    _selectedRowKey = rowKey;
    _selectionAnchorRowKey = rowKey;
    _bulkSelectedRowKeys
      ..clear()
      ..add(rowKey);
  }

  void _clearSelection() {
    _selectedRowKey = null;
    _selectionAnchorRowKey = null;
    _bulkSelectedRowKeys.clear();
  }

  void _removeSelectionKey(String rowKey) {
    _bulkSelectedRowKeys.remove(rowKey);
    if (_selectedRowKey == rowKey) {
      _selectedRowKey = _bulkSelectedRowKeys.isEmpty
          ? null
          : _bulkSelectedRowKeys.last;
    }
    if (_selectionAnchorRowKey == rowKey) {
      _selectionAnchorRowKey = _selectedRowKey;
    }
  }

  void _selectRange(String targetRowKey, List<String> visibleKeys) {
    final anchor = _selectionAnchorRowKey ?? _selectedRowKey ?? targetRowKey;
    final start = visibleKeys.indexOf(anchor);
    final end = visibleKeys.indexOf(targetRowKey);
    if (start == -1 || end == -1) {
      _setSingleSelection(targetRowKey);
      return;
    }
    final range = visibleKeys.sublist(
      start < end ? start : end,
      start < end ? end + 1 : start + 1,
    );
    _selectedRowKey = targetRowKey;
    _bulkSelectedRowKeys
      ..clear()
      ..addAll(range);
  }

  void _handleRowSelection(String rowKey, List<String> visibleKeys) {
    _gridRowsFocusNode.requestFocus();
    setState(() {
      if (_isShiftPressed()) {
        _selectRange(rowKey, visibleKeys);
        return;
      }
      if (_isCtrlOrCmdPressed()) {
        if (_bulkSelectedRowKeys.contains(rowKey)) {
          _bulkSelectedRowKeys.remove(rowKey);
          _selectedRowKey = _bulkSelectedRowKeys.isEmpty
              ? null
              : _bulkSelectedRowKeys.last;
        } else {
          _bulkSelectedRowKeys.add(rowKey);
          _selectedRowKey = rowKey;
        }
        _selectionAnchorRowKey ??= rowKey;
        return;
      }
      _setSingleSelection(rowKey);
    });
  }

  void _handleRowSecondarySelection(String rowKey, List<String> visibleKeys) {
    _gridRowsFocusNode.requestFocus();
    setState(() {
      if (_bulkSelectedRowKeys.contains(rowKey)) {
        _selectedRowKey = rowKey;
        _selectionAnchorRowKey ??= rowKey;
        return;
      }
      _setSingleSelection(rowKey);
    });
  }

  void _beginDragSelection(String rowKey, List<String> visibleKeys) {
    if (_isCtrlOrCmdPressed() || _isShiftPressed()) return;
    _gridRowsFocusNode.requestFocus();
    setState(() {
      _dragSelectionActive = true;
      _dragSelectionKeys = visibleKeys;
      _dragSelectionAnchorKey = rowKey;
      _setSingleSelection(rowKey);
    });
  }

  void _updateDragSelection(String rowKey) {
    if (!_dragSelectionActive || _dragSelectionAnchorKey == null) return;
    final visibleKeys = _dragSelectionKeys;
    final start = visibleKeys.indexOf(_dragSelectionAnchorKey!);
    final end = visibleKeys.indexOf(rowKey);
    if (start == -1 || end == -1) return;
    setState(() {
      final range = visibleKeys.sublist(
        start < end ? start : end,
        start < end ? end + 1 : start + 1,
      );
      _selectedRowKey = rowKey;
      _selectionAnchorRowKey = _dragSelectionAnchorKey;
      _bulkSelectedRowKeys
        ..clear()
        ..addAll(range);
    });
  }

  void _endDragSelection() {
    if (!_dragSelectionActive) return;
    setState(() {
      _dragSelectionActive = false;
      _dragSelectionKeys = const <String>[];
      _dragSelectionAnchorKey = null;
    });
  }

  bool _isRowSelected(String rowKey) => _bulkSelectedRowKeys.contains(rowKey);

  int get _selectedCount => _bulkSelectedRowKeys.length;

  List<String> _currentSelectionKeys() =>
      _bulkSelectedRowKeys.toList(growable: false);

  bool _isMultiContextRow(String rowKey) =>
      _selectedCount > 1 && _bulkSelectedRowKeys.contains(rowKey);

  bool _isInlineRowEditing(String rowKey) =>
      _editingRowKey == rowKey ||
      (_multiEditMode && _bulkSelectedRowKeys.contains(rowKey));

  GlobalKey<_CompanyInlineEditRowState> _companyEditKey(String rowKey) {
    return _companyEditRowKeys.putIfAbsent(
      rowKey,
      () => GlobalKey<_CompanyInlineEditRowState>(debugLabel: rowKey),
    );
  }

  GlobalKey<_MaterialInlineEditRowState> _materialEditKey(String rowKey) {
    return _materialEditRowKeys.putIfAbsent(
      rowKey,
      () => GlobalKey<_MaterialInlineEditRowState>(debugLabel: rowKey),
    );
  }

  GlobalKey<_PriceInlineEditRowState> _priceEditKey(String rowKey) {
    return _priceEditRowKeys.putIfAbsent(
      rowKey,
      () => GlobalKey<_PriceInlineEditRowState>(debugLabel: rowKey),
    );
  }

  bool get _hasEditingDraft => false;

  void _cancelActiveDraft() {
    _resetCompanyDraft();
    _resetMaterialDraft();
    _resetPriceDraft();
  }

  void _startInlineEdit(String rowKey) {
    setState(() {
      _cancelActiveDraft();
      _multiEditMode = false;
      _editingRowKey = rowKey;
      _setSingleSelection(rowKey);
    });
  }

  void _cancelInlineEdit() {
    if (_editingRowKey == null) return;
    setState(() => _editingRowKey = null);
    _focusGridRows();
  }

  void _startMultiEdit() {
    if (!mounted || _selectedCount <= 1) return;
    setState(() {
      _editingRowKey = null;
      _multiEditMode = true;
    });
    _focusGridRows();
  }

  void _cancelMultiEdit() {
    if (!mounted) return;
    setState(() => _multiEditMode = false);
  }

  void _cancelActiveMultiEdit() {
    for (final rowKey in _currentSelectionKeys()) {
      if (_activeTabIndex == 0) {
        _companyEditRowKeys[rowKey]?.currentState?.cancelFromParent();
      } else if (_activeTabIndex == 1) {
        _materialEditRowKeys[rowKey]?.currentState?.cancelFromParent();
      } else {
        _priceEditRowKeys[rowKey]?.currentState?.cancelFromParent();
      }
    }
    _cancelMultiEdit();
    _focusGridRows();
  }

  void _saveActiveMultiEdit() {
    for (final rowKey in _currentSelectionKeys()) {
      if (_activeTabIndex == 0) {
        _companyEditRowKeys[rowKey]?.currentState?.submitFromParent();
      } else if (_activeTabIndex == 1) {
        _materialEditRowKeys[rowKey]?.currentState?.submitFromParent();
      } else {
        _priceEditRowKeys[rowKey]?.currentState?.submitFromParent();
      }
    }
  }

  void _startEditSelection() {
    final rowKey = _selectedRowKey;
    if (rowKey == null) return;
    _startInlineEdit(rowKey);
  }

  void _saveCompanyInline(_MayoreoCompany row, Map<String, dynamic> payload) {
    final name = _normalizeName((payload['name'] ?? '').toString());
    if (name.isEmpty) {
      _toast('El nombre de la empresa es obligatorio');
      return;
    }
    setState(() {
      _companies = _companies
          .map(
            (item) => item.id == row.id
                ? item.copyWith(
                    name: name,
                    code: _codeFromName(name),
                    contact: _normalizeName(
                      (payload['contact'] ?? '').toString(),
                    ),
                    notes: (payload['notes'] ?? '').toString().trim(),
                    active: (payload['is_active'] ?? item.active) == true,
                  )
                : item,
          )
          .toList(growable: false);
      _editingRowKey = null;
      _setSingleSelection('co:${row.id}');
    });
    unawaited(_persistCatalogSnapshot());
    _focusGridRows();
  }

  void _saveMaterialInline(_MayoreoMaterial row, Map<String, dynamic> payload) {
    final name = _normalizeName((payload['name'] ?? '').toString());
    if (name.isEmpty) {
      _toast('El nombre del material es obligatorio');
      return;
    }
    final level = (payload['level'] ?? row.level).toString();
    final generalMaterialId = payload['generalMaterialId']?.toString();
    if (level == 'COMERCIAL' &&
        (generalMaterialId == null || generalMaterialId.isEmpty)) {
      _toast('Selecciona el material general de relación');
      return;
    }
    setState(() {
      _materials = _materials
          .map(
            (item) => item.id == row.id
                ? item.copyWith(
                    level: level,
                    name: name,
                    code: _codeFromName(name),
                    category: (payload['family'] ?? row.family ?? row.category)
                        .toString(),
                    family: level == 'GENERAL'
                        ? null
                        : (payload['family'] ?? row.family ?? row.category)
                              .toString(),
                    generalMaterialId: level == 'GENERAL'
                        ? null
                        : generalMaterialId,
                    clearFamily: level == 'GENERAL',
                    clearGeneralMaterialId: level == 'GENERAL',
                    notes: (payload['notes'] ?? '').toString().trim(),
                    active: (payload['is_active'] ?? item.active) == true,
                  )
                : item,
          )
          .toList(growable: false);
      _editingRowKey = null;
      _setSingleSelection('ma:${row.id}');
    });
    unawaited(_persistCatalogSnapshot());
    _focusGridRows();
  }

  void _savePriceInline(_MayoreoPrice row, Map<String, dynamic> payload) {
    final amount = double.tryParse(
      (payload['amount'] ?? '').toString().replaceAll(',', ''),
    );
    final companyId = payload['companyId']?.toString();
    final materialId = payload['materialId']?.toString();
    if (companyId == null || materialId == null || amount == null) {
      _toast('Empresa, material y precio son obligatorios');
      return;
    }
    setState(() {
      _prices = _prices
          .map(
            (item) => item.id == row.id
                ? item.copyWith(
                    companyId: companyId,
                    materialId: materialId,
                    amount: amount,
                    notes: (payload['notes'] ?? '').toString().trim(),
                    active: (payload['is_active'] ?? item.active) == true,
                    updatedAt: DateTime.now(),
                  )
                : item,
          )
          .toList(growable: false);
      _editingRowKey = null;
      _setSingleSelection('pr:${row.id}');
    });
    unawaited(_persistCatalogSnapshot());
    _focusGridRows();
  }

  void _deleteSelectedRows() {
    if (_bulkSelectedRowKeys.isEmpty) return;
    final keys = Set<String>.from(_bulkSelectedRowKeys);
    setState(() {
      switch (_activeTabIndex) {
        case 0:
          final blocked = _prices
              .map((row) => 'co:${row.companyId}')
              .where(keys.contains)
              .toSet();
          _companies = _companies
              .where(
                (row) =>
                    !keys.contains('co:${row.id}') ||
                    blocked.contains('co:${row.id}'),
              )
              .toList(growable: false);
          if (blocked.isNotEmpty) {
            _toast('Se omitieron empresas con precios activos');
          }
          break;
        case 1:
          final blocked = _prices
              .map((row) => 'ma:${row.materialId}')
              .where(keys.contains)
              .toSet();
          _materials = _materials
              .where(
                (row) =>
                    !keys.contains('ma:${row.id}') ||
                    blocked.contains('ma:${row.id}'),
              )
              .toList(growable: false);
          if (blocked.isNotEmpty) {
            _toast('Se omitieron materiales con precios activos');
          }
          break;
        default:
          _prices = _prices
              .where((row) => !keys.contains('pr:${row.id}'))
              .toList(growable: false);
      }
      _clearSelection();
    });
    unawaited(_persistCatalogSnapshot());
  }

  InventoryGridTopBarData _buildTopBarData() {
    switch (_activeTabIndex) {
      case 0:
        return InventoryGridTopBarData(
          metricIcon: Icons.business_rounded,
          metricLabel: 'EMPRESAS',
          metricValue: '${_visibleCompanies.length}',
          metricSubtitle: 'Filtrado (${_visibleCompanies.length} registros)',
          exportingCsv: false,
          gridEditMode: false,
          canToggleGridEdit: false,
          canDeleteSelection: _selectedCount > 0,
          deletingSelection: false,
          selectedCount: _selectedCount,
          onExportCsv: () => unawaited(_exportCurrentTab()),
          onDeleteSelection: () async => _deleteSelectedRows(),
        );
      case 1:
        return InventoryGridTopBarData(
          metricIcon: Icons.inventory_2_rounded,
          metricLabel: 'MATERIALES',
          metricValue: '${_visibleMaterials.length}',
          metricSubtitle: 'Filtrado (${_visibleMaterials.length} registros)',
          exportingCsv: false,
          gridEditMode: false,
          canToggleGridEdit: false,
          canDeleteSelection: _selectedCount > 0,
          deletingSelection: false,
          selectedCount: _selectedCount,
          onExportCsv: () => unawaited(_exportCurrentTab()),
          onDeleteSelection: () async => _deleteSelectedRows(),
        );
      default:
        return InventoryGridTopBarData(
          metricIcon: Icons.price_change_rounded,
          metricLabel: 'PRECIOS',
          metricValue: '${_visiblePrices.length}',
          metricSubtitle: 'Filtrado (${_visiblePrices.length} registros)',
          exportingCsv: false,
          gridEditMode: false,
          canToggleGridEdit: false,
          canDeleteSelection: _selectedCount > 0,
          deletingSelection: false,
          selectedCount: _selectedCount,
          onExportCsv: () => unawaited(_exportCurrentTab()),
          onDeleteSelection: () async => _deleteSelectedRows(),
        );
    }
  }

  KeyEventResult _handleGridKeyEvent(KeyEvent event, List<String> visibleKeys) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_isEditableTextFocused()) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final pressedSave =
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed) &&
        key == LogicalKeyboardKey.keyS;
    if (pressedSave && _multiEditMode) {
      _saveActiveMultiEdit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_menuOpen) {
        setState(() => _menuOpen = false);
        return KeyEventResult.handled;
      }
      if (_multiEditMode) {
        _cancelMultiEdit();
        return KeyEventResult.handled;
      }
      if (_editingRowKey != null) {
        _cancelInlineEdit();
        return KeyEventResult.handled;
      }
      if (_hasEditingDraft) {
        setState(_cancelActiveDraft);
        return KeyEventResult.handled;
      }
      if (_bulkSelectedRowKeys.isNotEmpty) {
        setState(_clearSelection);
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_editingRowKey != null) {
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
      _startEditSelection();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      if (_editingRowKey != null ||
          _multiEditMode ||
          _isEditableTextFocused() ||
          !_gridHasPrimaryKeyboardFocus) {
        return KeyEventResult.ignored;
      }
      _toggleSelectedActive();
      return KeyEventResult.handled;
    }

    if (visibleKeys.isEmpty) return KeyEventResult.ignored;
    final currentKey = _selectedRowKey ?? visibleKeys.first;
    final currentIndex = visibleKeys
        .indexOf(currentKey)
        .clamp(0, visibleKeys.length - 1);
    if (key == LogicalKeyboardKey.arrowDown) {
      final target =
          visibleKeys[(currentIndex + 1).clamp(0, visibleKeys.length - 1)];
      setState(() {
        if (_isShiftPressed()) {
          _selectRange(target, visibleKeys);
        } else {
          _setSingleSelection(target);
        }
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (currentIndex == 0 && !_isShiftPressed()) {
        _requestActiveInsertFocus();
        return KeyEventResult.handled;
      }
      final target =
          visibleKeys[(currentIndex - 1).clamp(0, visibleKeys.length - 1)];
      setState(() {
        if (_isShiftPressed()) {
          _selectRange(target, visibleKeys);
        } else {
          _setSingleSelection(target);
        }
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: mayoreoAreaTokens,
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
          background: const _MayoreoCatalogBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => _MayoreoHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => const _MayoreoCatalogHeaderBrand(),
          trailingBuilder: (_, _) => _MayoreoHeaderButton(
            label: 'Cerrar sesión',
            icon: Icons.logout_rounded,
            onTap: () async {},
          ),
          child: Stack(
            children: [
              _buildBody(),
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
                  child: _MayoreoCatalogSidePanel(
                    canReturnToDirection: _canReturnToDirection,
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

  Widget _buildBody() {
    final rowKeys = _currentRowKeys();
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(56, 0, 6, 0),
          child: Focus(
            focusNode: _gridRowsFocusNode,
            autofocus: true,
            onKeyEvent: (_, event) => _handleGridKeyEvent(event, rowKeys),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_editingRowKey != null ||
                    _hasEditingDraft ||
                    _bulkSelectedRowKeys.isNotEmpty) {
                  setState(() {
                    _editingRowKey = null;
                    _cancelActiveDraft();
                    _clearSelection();
                  });
                }
              },
              child: DefaultTabController(
                length: 3,
                initialIndex: _activeTabIndex,
                child: Builder(
                  builder: (context) {
                    final controller = DefaultTabController.of(context);
                    return AnimatedBuilder(
                      animation: controller.animation!,
                      builder: (context, _) {
                        if (_activeTabIndex != controller.index) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            setState(() {
                              _activeTabIndex = controller.index;
                              _clearSelection();
                            });
                          });
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
                              child: InventoryGridTopBar(
                                data: _buildTopBarData(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            AppFolderTabs(
                              controller: controller,
                              maxWidth: 760,
                              showBottomRail: false,
                              items: const [
                                AppFolderTabItem(
                                  label: 'Empresas',
                                  icon: Icons.business_rounded,
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
                                  _buildCompaniesTab(),
                                  _buildMaterialsTab(),
                                  _buildPricesTab(),
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
      ),
    );
  }

  Widget _buildCompaniesTab() {
    final visibleCompanies = _visibleCompanies;
    return _CatalogTabSurface(
      child: Column(
        children: [
          _CatalogFilterSummaryRow(
            labels: [
              for (final company in _companyNameFilters) 'Empresa: $company',
              for (final contact in _companyContactFilters)
                'Contacto: $contact',
              if (_companyActiveFilter != null)
                _companyActiveFilter!
                    ? 'Empresas activas'
                    : 'Empresas inactivas',
            ],
            onClearAll:
                _companyActiveFilter == null &&
                    _companyNameFilters.isEmpty &&
                    _companyContactFilters.isEmpty
                ? null
                : () => setState(() {
                    _companyActiveFilter = null;
                    _companyNameFilters = <String>{};
                    _companyContactFilters = <String>{};
                  }),
          ),
          const SizedBox(height: 10),
          _CatalogHeaderRow(
            contentWidth: _kCompanyContentW,
            columns: [
              _CatalogHeaderColumn(
                'EMPRESA',
                _kCompanyNameW,
                onFilter: _pickCompanyNameFilter,
                active: _companyNameFilters.isNotEmpty,
              ),
              _CatalogHeaderColumn(
                'CONTACTO',
                _kCompanyContactW,
                onFilter: _pickCompanyContactFilter,
                active: _companyContactFilters.isNotEmpty,
              ),
              _CatalogHeaderColumn(
                'ESTATUS',
                _kCompanyStatusW,
                onFilter: _pickCompanyActiveFilter,
                active: _companyActiveFilter != null,
              ),
              const _CatalogHeaderColumn('NOTAS', _kCompanyNotesW),
            ],
          ),
          const SizedBox(height: 10),
          _CompanyInsertRow(
            nameController: _companyNameC,
            contactController: _companyContactC,
            notesController: _companyNotesC,
            nameFocus: _companyNameFocus,
            contactFocus: _companyContactFocus,
            notesFocus: _companyNotesFocus,
            editing: false,
            onSubmit: _saveCompany,
            onFocusGrid: _focusGridRows,
            onTextNav: _handleInsertTextNavigation,
            onCancel: null,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: visibleCompanies.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = visibleCompanies[index];
                final rowKey = 'co:${row.id}';
                final visibleKeys = visibleCompanies
                    .map((item) => 'co:${item.id}')
                    .toList(growable: false);
                if (_isInlineRowEditing(rowKey)) {
                  return _CompanyInlineEditRow(
                    key: _companyEditKey(rowKey),
                    row: row,
                    onCancel: _multiEditMode
                        ? _cancelActiveMultiEdit
                        : _cancelInlineEdit,
                    onSave: (payload) => _saveCompanyInline(row, payload),
                  );
                }
                return _CatalogTableRow(
                  rowKey: rowKey,
                  selected: _isRowSelected(rowKey),
                  onTap: () => _handleRowSelection(rowKey, visibleKeys),
                  onPrimaryPointerDown: () =>
                      _beginDragSelection(rowKey, visibleKeys),
                  onDragEnter: () => _updateDragSelection(rowKey),
                  onPointerEnd: _endDragSelection,
                  onSecondarySelection: () =>
                      _handleRowSecondarySelection(rowKey, visibleKeys),
                  onDoubleTap: () => _startInlineEdit(rowKey),
                  cells: [
                    _CatalogTableCell.text(
                      width: _kCompanyNameW,
                      text: row.name,
                      bold: true,
                    ),
                    _CatalogTableCell.text(
                      width: _kCompanyContactW,
                      text: row.contact,
                    ),
                    _CatalogTableCell.chip(
                      width: _kCompanyStatusW,
                      label: row.active ? 'ACTIVO' : 'INACTIVO',
                      tone: row.active
                          ? const Color(0xFF2E8B57)
                          : const Color(0xFFB26A00),
                    ),
                    _CatalogTableCell.text(
                      width: _kCompanyNotesW,
                      text: row.notes,
                    ),
                  ],
                  editableColumns: const {0, 1, 3},
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
                            label: 'Activar / desactivar selección',
                            icon: Icons.toggle_on_rounded,
                            onTap: _toggleSelectedActive,
                          ),
                          _RowMenuAction(
                            label: 'Eliminar selección',
                            icon: Icons.delete_outline_rounded,
                            onTap: _deleteSelectedRows,
                          ),
                        ]
                      : [
                          _RowMenuAction(
                            label: 'Editar',
                            icon: Icons.edit_rounded,
                            onTap: () => _startInlineEdit(rowKey),
                          ),
                          _RowMenuAction(
                            label: row.active ? 'Desactivar' : 'Activar',
                            icon: row.active
                                ? Icons.pause_circle_rounded
                                : Icons.check_circle_rounded,
                            onTap: () => _toggleCompanyActive(row),
                          ),
                          _RowMenuAction(
                            label: 'Eliminar',
                            icon: Icons.delete_outline_rounded,
                            onTap: () => _deleteCompany(row),
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

  Widget _buildMaterialsTab() {
    final visibleMaterials = _visibleMaterials;
    return _CatalogTabSurface(
      child: Column(
        children: [
          _CatalogHeaderRow(
            contentWidth: _kMaterialContentW,
            columns: [
              _CatalogHeaderColumn(
                'NIVEL',
                _kMaterialLevelW,
                onFilter: _pickMaterialUnitFilter,
                active: _materialLevelFilters.isNotEmpty,
              ),
              _CatalogHeaderColumn(
                'MATERIAL',
                _kMaterialNameW,
                onFilter: _pickMaterialNameFilter,
                active: _materialNameFilters.isNotEmpty,
              ),
              _CatalogHeaderColumn(
                'FAMILIA',
                _kMaterialFamilyW,
                onFilter: _pickMaterialCategoryFilter,
                active: _materialFamilyFilters.isNotEmpty,
              ),
              _CatalogHeaderColumn(
                'RELACION',
                _kMaterialRelationW,
                onFilter: _pickMaterialRelationFilter,
                active: _materialRelationFilters.isNotEmpty,
              ),
              _CatalogHeaderColumn(
                'ESTATUS',
                _kMaterialStatusW,
                onFilter: _pickMaterialActiveFilter,
                active: _materialActiveFilter != null,
              ),
              const _CatalogHeaderColumn('NOTAS', _kMaterialNotesW),
            ],
          ),
          const SizedBox(height: 10),
          _CatalogFilterSummaryRow(
            labels: [
              for (final level in _materialLevelFilters) 'Nivel: $level',
              for (final material in _materialNameFilters)
                'Material: $material',
              for (final family in _materialFamilyFilters) 'Familia: $family',
              for (final relation in _materialRelationFilters)
                'Relacion: $relation',
              if (_materialActiveFilter != null)
                _materialActiveFilter!
                    ? 'Materiales activos'
                    : 'Materiales inactivos',
            ],
            onClearAll:
                _materialLevelFilters.isEmpty &&
                    _materialNameFilters.isEmpty &&
                    _materialFamilyFilters.isEmpty &&
                    _materialRelationFilters.isEmpty &&
                    _materialActiveFilter == null
                ? null
                : () => setState(() {
                    _materialLevelFilters = <String>{};
                    _materialNameFilters = <String>{};
                    _materialFamilyFilters = <String>{};
                    _materialRelationFilters = <String>{};
                    _materialActiveFilter = null;
                  }),
          ),
          const SizedBox(height: 10),
          _MaterialInsertRow(
            generalMaterials: _generalMaterials,
            nameController: _materialNameC,
            notesController: _materialNotesC,
            levelFocus: _materialLevelFocus,
            nameFocus: _materialNameFocus,
            familyFocus: _materialFamilyFocus,
            relationFocus: _materialRelationFocus,
            notesFocus: _materialNotesFocus,
            level: _materialLevel,
            family: _materialFamily,
            selectedGeneralMaterialId: _materialGeneralMaterialId,
            editing: false,
            onLevelChanged: (value) => setState(() {
              _materialLevel = value;
              if (value == 'GENERAL') {
                _materialGeneralMaterialId = null;
              }
            }),
            onFamilyChanged: (value) => setState(() => _materialFamily = value),
            onGeneralMaterialChanged: (value) =>
                setState(() => _materialGeneralMaterialId = value),
            onSubmit: _saveMaterial,
            onFocusGrid: _focusGridRows,
            onTextNav: _handleInsertTextNavigation,
            onCancel: null,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: visibleMaterials.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = visibleMaterials[index];
                final rowKey = 'ma:${row.id}';
                final visibleKeys = visibleMaterials
                    .map((item) => 'ma:${item.id}')
                    .toList(growable: false);
                if (_isInlineRowEditing(rowKey)) {
                  return _MaterialInlineEditRow(
                    key: _materialEditKey(rowKey),
                    row: row,
                    generalMaterials: _generalMaterials,
                    onCancel: _multiEditMode
                        ? _cancelActiveMultiEdit
                        : _cancelInlineEdit,
                    onSave: (payload) => _saveMaterialInline(row, payload),
                  );
                }
                return _CatalogTableRow(
                  rowKey: rowKey,
                  selected: _isRowSelected(rowKey),
                  onTap: () => _handleRowSelection(rowKey, visibleKeys),
                  onPrimaryPointerDown: () =>
                      _beginDragSelection(rowKey, visibleKeys),
                  onDragEnter: () => _updateDragSelection(rowKey),
                  onPointerEnd: _endDragSelection,
                  onSecondarySelection: () =>
                      _handleRowSecondarySelection(rowKey, visibleKeys),
                  onDoubleTap: () => _startInlineEdit(rowKey),
                  cells: [
                    _CatalogTableCell.chip(
                      width: _kMaterialLevelW,
                      label: row.level,
                      tone: row.level == 'GENERAL'
                          ? const Color(0xFF8E3F2A)
                          : const Color(0xFFE89A5B),
                    ),
                    _CatalogTableCell.text(
                      width: _kMaterialNameW,
                      text: row.name,
                      bold: true,
                    ),
                    _CatalogTableCell.chip(
                      width: _kMaterialFamilyW,
                      label: row.level == 'GENERAL'
                          ? '—'
                          : (row.family ?? row.category),
                      tone: const Color(0xFF9A6A00),
                    ),
                    _CatalogTableCell.text(
                      width: _kMaterialRelationW,
                      text: row.level == 'GENERAL'
                          ? 'Catalogo base'
                          : _materialRelationLabel(row.generalMaterialId),
                    ),
                    _CatalogTableCell.chip(
                      width: _kMaterialStatusW,
                      label: row.active ? 'ACTIVO' : 'INACTIVO',
                      tone: row.active
                          ? const Color(0xFF2E8B57)
                          : const Color(0xFFB26A00),
                    ),
                    _CatalogTableCell.text(
                      width: _kMaterialNotesW,
                      text: row.notes,
                    ),
                  ],
                  editableColumns: const {1, 2, 3, 4, 5},
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
                            label: 'Activar / desactivar selección',
                            icon: Icons.toggle_on_rounded,
                            onTap: _toggleSelectedActive,
                          ),
                          _RowMenuAction(
                            label: 'Eliminar selección',
                            icon: Icons.delete_outline_rounded,
                            onTap: _deleteSelectedRows,
                          ),
                        ]
                      : [
                          _RowMenuAction(
                            label: 'Editar',
                            icon: Icons.edit_rounded,
                            onTap: () => _startInlineEdit(rowKey),
                          ),
                          _RowMenuAction(
                            label: row.active ? 'Desactivar' : 'Activar',
                            icon: row.active
                                ? Icons.pause_circle_rounded
                                : Icons.check_circle_rounded,
                            onTap: () => _toggleMaterialActive(row),
                          ),
                          _RowMenuAction(
                            label: 'Eliminar',
                            icon: Icons.delete_outline_rounded,
                            onTap: () => _deleteMaterial(row),
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

  Widget _buildPricesTab() {
    final visiblePrices = _visiblePrices;
    return _CatalogTabSurface(
      child: Column(
        children: [
          _CatalogHeaderRow(
            contentWidth: _kPriceContentW,
            columns: [
              _CatalogHeaderColumn(
                'EMPRESA',
                _kPriceCompanyW,
                onFilter: _pickPriceCompanyFilter,
                active: _priceCompanyFilterId != null,
              ),
              _CatalogHeaderColumn(
                'MATERIAL',
                _kPriceMaterialW,
                onFilter: _pickPriceMaterialFilter,
                active: _priceMaterialFilterId != null,
              ),
              const _CatalogHeaderColumn('PRECIO', _kPriceAmountW),
              _CatalogHeaderColumn(
                'ESTATUS',
                _kPriceStatusW,
                onFilter: _pickPriceActiveFilter,
                active: _priceActiveFilter != null,
              ),
              const _CatalogHeaderColumn('NOTAS', _kPriceNotesW),
            ],
          ),
          const SizedBox(height: 10),
          _CatalogFilterSummaryRow(
            labels: [
              if (_priceCompanyFilterId != null)
                'Empresa: ${_companyName(_priceCompanyFilterId!)}',
              if (_priceMaterialFilterId != null)
                'Material: ${_materialName(_priceMaterialFilterId!)}',
              if (_priceActiveFilter != null)
                _priceActiveFilter! ? 'Precios activos' : 'Precios inactivos',
            ],
            onClearAll:
                _priceCompanyFilterId == null &&
                    _priceMaterialFilterId == null &&
                    _priceActiveFilter == null
                ? null
                : () => setState(() {
                    _priceCompanyFilterId = null;
                    _priceMaterialFilterId = null;
                    _priceActiveFilter = null;
                  }),
          ),
          const SizedBox(height: 10),
          _PriceInsertRow(
            companies: _companies,
            materials: _commercialMaterials.where((row) => row.active).toList(),
            selectedCompanyId: _priceCompanyId,
            selectedMaterialId: _priceMaterialId,
            amountController: _priceAmountC,
            notesController: _priceNotesC,
            companyFocus: _priceCompanyFocus,
            materialFocus: _priceMaterialFocus,
            amountFocus: _priceAmountFocus,
            notesFocus: _priceNotesFocus,
            editing: false,
            onCompanyChanged: (value) =>
                setState(() => _priceCompanyId = value),
            onMaterialChanged: (value) =>
                setState(() => _priceMaterialId = value),
            onSubmit: _savePrice,
            onFocusGrid: _focusGridRows,
            onTextNav: _handleInsertTextNavigation,
            onCancel: null,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: visiblePrices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = visiblePrices[index];
                final rowKey = 'pr:${row.id}';
                final visibleKeys = visiblePrices
                    .map((item) => 'pr:${item.id}')
                    .toList(growable: false);
                if (_isInlineRowEditing(rowKey)) {
                  return _PriceInlineEditRow(
                    key: _priceEditKey(rowKey),
                    row: row,
                    companies: _companies,
                    materials: _commercialMaterials,
                    onCancel: _multiEditMode
                        ? _cancelActiveMultiEdit
                        : _cancelInlineEdit,
                    onSave: (payload) => _savePriceInline(row, payload),
                  );
                }
                return _CatalogTableRow(
                  rowKey: rowKey,
                  selected: _isRowSelected(rowKey),
                  onTap: () => _handleRowSelection(rowKey, visibleKeys),
                  onPrimaryPointerDown: () =>
                      _beginDragSelection(rowKey, visibleKeys),
                  onDragEnter: () => _updateDragSelection(rowKey),
                  onPointerEnd: _endDragSelection,
                  onSecondarySelection: () =>
                      _handleRowSecondarySelection(rowKey, visibleKeys),
                  onDoubleTap: () => _startInlineEdit(rowKey),
                  cells: [
                    _CatalogTableCell.text(
                      width: _kPriceCompanyW,
                      text: _companyName(row.companyId),
                      bold: true,
                    ),
                    _CatalogTableCell.text(
                      width: _kPriceMaterialW,
                      text: _materialName(row.materialId),
                    ),
                    _CatalogTableCell.text(
                      width: _kPriceAmountW,
                      text: _money(row.amount),
                    ),
                    _CatalogTableCell.chip(
                      width: _kPriceStatusW,
                      label: row.active ? 'ACTIVO' : 'INACTIVO',
                      tone: row.active
                          ? const Color(0xFF2E8B57)
                          : const Color(0xFFB26A00),
                    ),
                    _CatalogTableCell.text(
                      width: _kPriceNotesW,
                      text: row.notes,
                    ),
                  ],
                  editableColumns: const {0, 1, 2, 4},
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
                            label: 'Activar / desactivar selección',
                            icon: Icons.toggle_on_rounded,
                            onTap: _toggleSelectedActive,
                          ),
                          _RowMenuAction(
                            label: 'Eliminar selección',
                            icon: Icons.delete_outline_rounded,
                            onTap: _deleteSelectedRows,
                          ),
                        ]
                      : [
                          _RowMenuAction(
                            label: 'Editar',
                            icon: Icons.edit_rounded,
                            onTap: () => _startInlineEdit(rowKey),
                          ),
                          _RowMenuAction(
                            label: row.active ? 'Desactivar' : 'Activar',
                            icon: row.active
                                ? Icons.pause_circle_rounded
                                : Icons.check_circle_rounded,
                            onTap: () => _togglePriceActive(row),
                          ),
                          _RowMenuAction(
                            label: 'Eliminar',
                            icon: Icons.delete_outline_rounded,
                            onTap: () => _deletePrice(row),
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

class _CompanyInsertRow extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController contactController;
  final TextEditingController notesController;
  final FocusNode nameFocus;
  final FocusNode contactFocus;
  final FocusNode notesFocus;
  final bool editing;
  final VoidCallback onSubmit;
  final VoidCallback onFocusGrid;
  final VoidCallback? onCancel;
  final KeyEventResult Function({
    required KeyEvent event,
    required TextEditingController controller,
    FocusNode? previous,
    FocusNode? next,
    VoidCallback? onDown,
    VoidCallback? onEnter,
  })?
  onTextNav;

  const _CompanyInsertRow({
    required this.nameController,
    required this.contactController,
    required this.notesController,
    required this.nameFocus,
    required this.contactFocus,
    required this.notesFocus,
    required this.editing,
    required this.onSubmit,
    required this.onFocusGrid,
    this.onTextNav,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return _CatalogInlineInsertRow(
      contentWidth: _kCompanyContentW,
      editing: editing,
      statusLabel: editing ? 'EDITANDO EMPRESA' : null,
      actionChild: editing
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onCancel != null)
                  _CatalogInlineActionButton(
                    onTap: onCancel,
                    icon: Icons.close_rounded,
                    color: const Color(0xFF8F6D5A),
                  ),
                if (onCancel != null) const SizedBox(width: 8),
                _CatalogInlineActionButton(
                  onTap: onSubmit,
                  icon: Icons.check_rounded,
                  color: const Color(0xFF19C37D),
                ),
              ],
            )
          : _CatalogInlineAddButton(loading: false, onTap: onSubmit),
      children: [
        _CatalogInlineFieldCell(
          width: _kCompanyNameW,
          child: Focus(
            onKeyEvent: (_, event) =>
                onTextNav?.call(
                  event: event,
                  controller: nameController,
                  next: contactFocus,
                  onDown: onFocusGrid,
                  onEnter: onSubmit,
                ) ??
                KeyEventResult.ignored,
            child: TextField(
              controller: nameController,
              focusNode: nameFocus,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [_normalizedUppercaseFormatter()],
              onSubmitted: (_) => contactFocus.requestFocus(),
              decoration: contractGlassFieldDecoration(
                context,
                hintText: 'Nueva empresa',
              ),
            ),
          ),
        ),
        _CatalogInlineFieldCell(
          width: _kCompanyContactW,
          child: Focus(
            onKeyEvent: (_, event) =>
                onTextNav?.call(
                  event: event,
                  controller: contactController,
                  previous: nameFocus,
                  next: notesFocus,
                  onDown: onFocusGrid,
                  onEnter: onSubmit,
                ) ??
                KeyEventResult.ignored,
            child: TextField(
              controller: contactController,
              focusNode: contactFocus,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [_normalizedUppercaseFormatter()],
              onSubmitted: (_) => notesFocus.requestFocus(),
              decoration: contractGlassFieldDecoration(
                context,
                hintText: 'Contacto',
              ),
            ),
          ),
        ),
        const _CatalogInlineFieldCell(
          width: _kCompanyStatusW,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ACTIVO',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        _CatalogInlineFieldCell(
          width: _kCompanyNotesW,
          child: Focus(
            onKeyEvent: (_, event) =>
                onTextNav?.call(
                  event: event,
                  controller: notesController,
                  previous: contactFocus,
                  onDown: onFocusGrid,
                  onEnter: onSubmit,
                ) ??
                KeyEventResult.ignored,
            child: TextField(
              controller: notesController,
              focusNode: notesFocus,
              onSubmitted: (_) => onSubmit(),
              decoration: contractGlassFieldDecoration(
                context,
                hintText: 'Notas',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MaterialInsertRow extends StatelessWidget {
  final List<_MayoreoMaterial> generalMaterials;
  final TextEditingController nameController;
  final TextEditingController notesController;
  final FocusNode levelFocus;
  final FocusNode nameFocus;
  final FocusNode familyFocus;
  final FocusNode relationFocus;
  final FocusNode notesFocus;
  final String level;
  final String family;
  final String? selectedGeneralMaterialId;
  final bool editing;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onFamilyChanged;
  final ValueChanged<String?> onGeneralMaterialChanged;
  final VoidCallback onSubmit;
  final VoidCallback onFocusGrid;
  final VoidCallback? onCancel;
  final KeyEventResult Function({
    required KeyEvent event,
    required TextEditingController controller,
    FocusNode? previous,
    FocusNode? next,
    VoidCallback? onDown,
    VoidCallback? onEnter,
  })?
  onTextNav;

  const _MaterialInsertRow({
    required this.generalMaterials,
    required this.nameController,
    required this.notesController,
    required this.levelFocus,
    required this.nameFocus,
    required this.familyFocus,
    required this.relationFocus,
    required this.notesFocus,
    required this.level,
    required this.family,
    required this.selectedGeneralMaterialId,
    required this.editing,
    required this.onLevelChanged,
    required this.onFamilyChanged,
    required this.onGeneralMaterialChanged,
    required this.onSubmit,
    required this.onFocusGrid,
    this.onTextNav,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return _CatalogInlineInsertRow(
      contentWidth: _kMaterialContentW,
      editing: editing,
      statusLabel: editing
          ? (level == 'GENERAL'
                ? 'EDITANDO MATERIAL GENERAL'
                : 'EDITANDO MATERIAL COMERCIAL')
          : null,
      actionChild: editing
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onCancel != null)
                  _CatalogInlineActionButton(
                    onTap: onCancel,
                    icon: Icons.close_rounded,
                    color: const Color(0xFF8F6D5A),
                  ),
                if (onCancel != null) const SizedBox(width: 8),
                _CatalogInlineActionButton(
                  onTap: onSubmit,
                  icon: Icons.check_rounded,
                  color: const Color(0xFF19C37D),
                ),
              ],
            )
          : _CatalogInlineAddButton(loading: false, onTap: onSubmit),
      children: [
        _CatalogInlineFieldCell(
          width: _kMaterialLevelW,
          child: _CatalogDropdownField<String>(
            value: level,
            focusNode: levelFocus,
            nextFocusNode: nameFocus,
            hint: 'Nivel',
            title: 'Seleccionar nivel',
            items: const ['GENERAL', 'COMERCIAL'],
            onChanged: (value) {
              if (value != null) onLevelChanged(value);
            },
            onDown: onFocusGrid,
          ),
        ),
        _CatalogInlineFieldCell(
          width: _kMaterialNameW,
          child: Focus(
            onKeyEvent: (_, event) =>
                onTextNav?.call(
                  event: event,
                  controller: nameController,
                  previous: levelFocus,
                  next: level == 'GENERAL' ? notesFocus : familyFocus,
                  onDown: onFocusGrid,
                  onEnter: onSubmit,
                ) ??
                KeyEventResult.ignored,
            child: TextField(
              controller: nameController,
              focusNode: nameFocus,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [_normalizedUppercaseFormatter()],
              onSubmitted: (_) => level == 'GENERAL'
                  ? notesFocus.requestFocus()
                  : familyFocus.requestFocus(),
              decoration: contractGlassFieldDecoration(
                context,
                hintText: 'Nuevo material',
              ),
            ),
          ),
        ),
        _CatalogInlineFieldCell(
          width: _kMaterialFamilyW,
          child: level == 'GENERAL'
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '—',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                )
              : _CatalogDropdownField<String>(
                  value: family,
                  focusNode: familyFocus,
                  previousFocusNode: nameFocus,
                  nextFocusNode: relationFocus,
                  title: 'Seleccionar familia',
                  hint: 'Familia',
                  items: _kMayoreoGeneralCategories,
                  onChanged: (value) {
                    if (value != null) onFamilyChanged(value);
                  },
                  onDown: onFocusGrid,
                ),
        ),
        _CatalogInlineFieldCell(
          width: _kMaterialRelationW,
          child: level == 'GENERAL'
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Catalogo base',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                )
              : _CatalogDropdownField<String?>(
                  value: selectedGeneralMaterialId,
                  focusNode: relationFocus,
                  previousFocusNode: familyFocus,
                  nextFocusNode: notesFocus,
                  title: 'Seleccionar material general',
                  hint: 'Relacion',
                  items: generalMaterials
                      .where((row) => row.active)
                      .map((row) => row.id)
                      .toList(growable: false),
                  labelBuilder: (value) => generalMaterials
                      .firstWhere((row) => row.id == value)
                      .name,
                  onChanged: onGeneralMaterialChanged,
                  onDown: onFocusGrid,
                ),
        ),
        const _CatalogInlineFieldCell(
          width: _kMaterialStatusW,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ACTIVO',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        _CatalogInlineFieldCell(
          width: _kMaterialNotesW,
          child: Focus(
            onKeyEvent: (_, event) =>
                onTextNav?.call(
                  event: event,
                  controller: notesController,
                  previous: level == 'GENERAL' ? nameFocus : relationFocus,
                  onDown: onFocusGrid,
                  onEnter: onSubmit,
                ) ??
                KeyEventResult.ignored,
            child: TextField(
              controller: notesController,
              focusNode: notesFocus,
              onSubmitted: (_) => onSubmit(),
              decoration: contractGlassFieldDecoration(
                context,
                hintText: 'Notas',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceInsertRow extends StatelessWidget {
  final List<_MayoreoCompany> companies;
  final List<_MayoreoMaterial> materials;
  final String? selectedCompanyId;
  final String? selectedMaterialId;
  final TextEditingController amountController;
  final TextEditingController notesController;
  final FocusNode companyFocus;
  final FocusNode materialFocus;
  final FocusNode amountFocus;
  final FocusNode notesFocus;
  final bool editing;
  final ValueChanged<String?> onCompanyChanged;
  final ValueChanged<String?> onMaterialChanged;
  final VoidCallback onSubmit;
  final VoidCallback onFocusGrid;
  final VoidCallback? onCancel;
  final KeyEventResult Function({
    required KeyEvent event,
    required TextEditingController controller,
    FocusNode? previous,
    FocusNode? next,
    VoidCallback? onDown,
    VoidCallback? onEnter,
  })?
  onTextNav;

  const _PriceInsertRow({
    required this.companies,
    required this.materials,
    required this.selectedCompanyId,
    required this.selectedMaterialId,
    required this.amountController,
    required this.notesController,
    required this.companyFocus,
    required this.materialFocus,
    required this.amountFocus,
    required this.notesFocus,
    required this.editing,
    required this.onCompanyChanged,
    required this.onMaterialChanged,
    required this.onSubmit,
    required this.onFocusGrid,
    this.onTextNav,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return _CatalogInlineInsertRow(
      contentWidth: _kPriceContentW,
      editing: editing,
      statusLabel: editing ? 'EDITANDO PRECIO' : null,
      actionChild: editing
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onCancel != null)
                  _CatalogInlineActionButton(
                    onTap: onCancel,
                    icon: Icons.close_rounded,
                    color: const Color(0xFF8F6D5A),
                  ),
                if (onCancel != null) const SizedBox(width: 8),
                _CatalogInlineActionButton(
                  onTap: onSubmit,
                  icon: Icons.check_rounded,
                  color: const Color(0xFF19C37D),
                ),
              ],
            )
          : _CatalogInlineAddButton(loading: false, onTap: onSubmit),
      children: [
        _CatalogInlineFieldCell(
          width: _kPriceCompanyW,
          child: _CatalogDropdownField<String?>(
            value: selectedCompanyId,
            focusNode: companyFocus,
            nextFocusNode: materialFocus,
            hint: 'Empresa',
            title: 'Seleccionar empresa',
            items: companies.map((row) => row.id).toList(growable: false),
            labelBuilder: (value) =>
                companies.firstWhere((row) => row.id == value).name,
            onChanged: onCompanyChanged,
            onDown: onFocusGrid,
          ),
        ),
        _CatalogInlineFieldCell(
          width: _kPriceMaterialW,
          child: _CatalogDropdownField<String?>(
            value: selectedMaterialId,
            focusNode: materialFocus,
            previousFocusNode: companyFocus,
            nextFocusNode: amountFocus,
            hint: 'Material',
            title: 'Seleccionar material',
            items: materials.map((row) => row.id).toList(growable: false),
            labelBuilder: (value) =>
                materials.firstWhere((row) => row.id == value).name,
            onChanged: onMaterialChanged,
            onDown: onFocusGrid,
          ),
        ),
        _CatalogInlineFieldCell(
          width: _kPriceAmountW,
          child: Focus(
            onKeyEvent: (_, event) =>
                onTextNav?.call(
                  event: event,
                  controller: amountController,
                  previous: materialFocus,
                  next: notesFocus,
                  onDown: onFocusGrid,
                  onEnter: onSubmit,
                ) ??
                KeyEventResult.ignored,
            child: TextField(
              controller: amountController,
              focusNode: amountFocus,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onSubmitted: (_) => notesFocus.requestFocus(),
              decoration: contractGlassFieldDecoration(
                context,
                hintText: 'Precio',
              ),
            ),
          ),
        ),
        const _CatalogInlineFieldCell(
          width: _kPriceStatusW,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ACTIVO',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        _CatalogInlineFieldCell(
          width: _kPriceNotesW,
          child: Focus(
            onKeyEvent: (_, event) =>
                onTextNav?.call(
                  event: event,
                  controller: notesController,
                  previous: amountFocus,
                  onDown: onFocusGrid,
                  onEnter: onSubmit,
                ) ??
                KeyEventResult.ignored,
            child: TextField(
              controller: notesController,
              focusNode: notesFocus,
              onSubmitted: (_) => onSubmit(),
              decoration: contractGlassFieldDecoration(
                context,
                hintText: 'Notas',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompanyInlineEditRow extends StatefulWidget {
  final _MayoreoCompany row;
  final VoidCallback onCancel;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _CompanyInlineEditRow({
    super.key,
    required this.row,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_CompanyInlineEditRow> createState() => _CompanyInlineEditRowState();
}

class _CompanyInlineEditRowState extends State<_CompanyInlineEditRow> {
  late final TextEditingController _nameC;
  late final TextEditingController _contactC;
  late final TextEditingController _notesC;
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _contactFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.row.name);
    _contactC = TextEditingController(text: widget.row.contact);
    _notesC = TextEditingController(text: widget.row.notes);
    _isActive = widget.row.active;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _contactC.dispose();
    _notesC.dispose();
    _nameFocus.dispose();
    _contactFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSave({
      'name': _nameC.text,
      'contact': _contactC.text,
      'notes': _notesC.text,
      'is_active': _isActive,
    });
  }

  void submitFromParent() => _submit();

  void cancelFromParent() => widget.onCancel();

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) => widget.onCancel(),
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onCancel();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            _submit();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: _CatalogInlineInsertRow(
          contentWidth: _kCompanyContentW,
          editing: true,
          statusLabel: 'EDITANDO EMPRESA',
          actionChild: Row(
            mainAxisSize: MainAxisSize.min,
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
              width: _kCompanyNameW,
              child: TextField(
                controller: _nameC,
                focusNode: _nameFocus,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [_normalizedUppercaseFormatter()],
                onSubmitted: (_) => _contactFocus.requestFocus(),
                decoration: contractGlassFieldDecoration(
                  context,
                  hintText: 'Empresa',
                ),
              ),
            ),
            _CatalogInlineFieldCell(
              width: _kCompanyContactW,
              child: TextField(
                controller: _contactC,
                focusNode: _contactFocus,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [_normalizedUppercaseFormatter()],
                onSubmitted: (_) => _notesFocus.requestFocus(),
                decoration: contractGlassFieldDecoration(
                  context,
                  hintText: 'Contacto',
                ),
              ),
            ),
            _CatalogInlineFieldCell(
              width: _kCompanyStatusW,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Switch(
                  value: _isActive,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ),
            ),
            _CatalogInlineFieldCell(
              width: _kCompanyNotesW,
              child: TextField(
                controller: _notesC,
                focusNode: _notesFocus,
                onSubmitted: (_) => _submit(),
                decoration: contractGlassFieldDecoration(
                  context,
                  hintText: 'Notas',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialInlineEditRow extends StatefulWidget {
  final _MayoreoMaterial row;
  final List<_MayoreoMaterial> generalMaterials;
  final VoidCallback onCancel;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _MaterialInlineEditRow({
    super.key,
    required this.row,
    required this.generalMaterials,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_MaterialInlineEditRow> createState() => _MaterialInlineEditRowState();
}

class _MaterialInlineEditRowState extends State<_MaterialInlineEditRow> {
  late final TextEditingController _nameC;
  late final TextEditingController _notesC;
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _familyFocus = FocusNode();
  final FocusNode _relationFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();
  late String _level;
  late String _family;
  String? _generalMaterialId;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.row.name);
    _notesC = TextEditingController(text: widget.row.notes);
    _level = widget.row.level;
    _family = widget.row.family ?? widget.row.category;
    _generalMaterialId = widget.row.generalMaterialId;
    _isActive = widget.row.active;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _notesC.dispose();
    _nameFocus.dispose();
    _familyFocus.dispose();
    _relationFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSave({
      'level': _level,
      'name': _nameC.text,
      'family': _family,
      'generalMaterialId': _generalMaterialId,
      'notes': _notesC.text,
      'is_active': _isActive,
    });
  }

  void submitFromParent() => _submit();

  void cancelFromParent() => widget.onCancel();

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) => widget.onCancel(),
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onCancel();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            _submit();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: _CatalogInlineInsertRow(
          contentWidth: _kMaterialContentW,
          editing: true,
          statusLabel: _level == 'GENERAL'
              ? 'EDITANDO MATERIAL GENERAL'
              : 'EDITANDO MATERIAL COMERCIAL',
          actionChild: Row(
            mainAxisSize: MainAxisSize.min,
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
              width: _kMaterialLevelW,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _RowChip(
                  label: _level,
                  tone: _level == 'GENERAL'
                      ? const Color(0xFF8E3F2A)
                      : const Color(0xFFE89A5B),
                ),
              ),
            ),
            _CatalogInlineFieldCell(
              width: _kMaterialNameW,
              child: TextField(
                controller: _nameC,
                focusNode: _nameFocus,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [_normalizedUppercaseFormatter()],
                onSubmitted: (_) => _level == 'GENERAL'
                    ? _notesFocus.requestFocus()
                    : _familyFocus.requestFocus(),
                decoration: contractGlassFieldDecoration(
                  context,
                  hintText: 'Material',
                ),
              ),
            ),
            _CatalogInlineFieldCell(
              width: _kMaterialFamilyW,
              child: _level == 'GENERAL'
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '—',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    )
                  : _CatalogDropdownField<String>(
                      value: _family,
                      focusNode: _familyFocus,
                      previousFocusNode: _nameFocus,
                      nextFocusNode: _relationFocus,
                      hint: 'Familia',
                      title: 'Seleccionar familia',
                      items: _kMayoreoGeneralCategories,
                      onChanged: (value) {
                        if (value != null) setState(() => _family = value);
                      },
                    ),
            ),
            _CatalogInlineFieldCell(
              width: _kMaterialRelationW,
              child: _level == 'GENERAL'
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Catalogo base',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    )
                  : _CatalogDropdownField<String?>(
                      value: _generalMaterialId,
                      focusNode: _relationFocus,
                      previousFocusNode: _familyFocus,
                      nextFocusNode: _notesFocus,
                      hint: 'Relacion',
                      title: 'Seleccionar material general',
                      items: widget.generalMaterials
                          .where((row) => row.active)
                          .map((row) => row.id)
                          .toList(growable: false),
                      labelBuilder: (value) => widget.generalMaterials
                          .firstWhere((row) => row.id == value)
                          .name,
                      onChanged: (value) =>
                          setState(() => _generalMaterialId = value),
                    ),
            ),
            _CatalogInlineFieldCell(
              width: _kMaterialStatusW,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Switch(
                  value: _isActive,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ),
            ),
            _CatalogInlineFieldCell(
              width: _kMaterialNotesW,
              child: TextField(
                controller: _notesC,
                focusNode: _notesFocus,
                onSubmitted: (_) => _submit(),
                decoration: contractGlassFieldDecoration(
                  context,
                  hintText: 'Notas',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceInlineEditRow extends StatefulWidget {
  final _MayoreoPrice row;
  final List<_MayoreoCompany> companies;
  final List<_MayoreoMaterial> materials;
  final VoidCallback onCancel;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _PriceInlineEditRow({
    super.key,
    required this.row,
    required this.companies,
    required this.materials,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_PriceInlineEditRow> createState() => _PriceInlineEditRowState();
}

class _PriceInlineEditRowState extends State<_PriceInlineEditRow> {
  String? _companyId;
  String? _materialId;
  late final TextEditingController _amountC;
  late final TextEditingController _notesC;
  final FocusNode _companyFocus = FocusNode();
  final FocusNode _materialFocus = FocusNode();
  final FocusNode _amountFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _companyId = widget.row.companyId;
    _materialId = widget.row.materialId;
    _amountC = TextEditingController(
      text: widget.row.amount.toStringAsFixed(2),
    );
    _notesC = TextEditingController(text: widget.row.notes);
    _isActive = widget.row.active;
  }

  @override
  void dispose() {
    _amountC.dispose();
    _notesC.dispose();
    _companyFocus.dispose();
    _materialFocus.dispose();
    _amountFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSave({
      'companyId': _companyId,
      'materialId': _materialId,
      'amount': _amountC.text,
      'notes': _notesC.text,
      'is_active': _isActive,
    });
  }

  void submitFromParent() => _submit();

  void cancelFromParent() => widget.onCancel();

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) => widget.onCancel(),
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onCancel();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            _submit();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: _CatalogInlineInsertRow(
          contentWidth: _kPriceContentW,
          editing: true,
          statusLabel: 'EDITANDO PRECIO',
          actionChild: Row(
            mainAxisSize: MainAxisSize.min,
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
              width: _kPriceCompanyW,
              child: _CatalogDropdownField<String?>(
                value: _companyId,
                focusNode: _companyFocus,
                nextFocusNode: _materialFocus,
                hint: 'Empresa',
                title: 'Seleccionar empresa',
                items: widget.companies
                    .map((company) => company.id)
                    .toList(growable: false),
                labelBuilder: (value) => widget.companies
                    .firstWhere((company) => company.id == value)
                    .name,
                onChanged: (value) => setState(() => _companyId = value),
              ),
            ),
            _CatalogInlineFieldCell(
              width: _kPriceMaterialW,
              child: _CatalogDropdownField<String?>(
                value: _materialId,
                focusNode: _materialFocus,
                previousFocusNode: _companyFocus,
                nextFocusNode: _amountFocus,
                hint: 'Material',
                title: 'Seleccionar material',
                items: widget.materials
                    .map((material) => material.id)
                    .toList(growable: false),
                labelBuilder: (value) => widget.materials
                    .firstWhere((material) => material.id == value)
                    .name,
                onChanged: (value) => setState(() => _materialId = value),
              ),
            ),
            _CatalogInlineFieldCell(
              width: _kPriceAmountW,
              child: TextField(
                controller: _amountC,
                focusNode: _amountFocus,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onSubmitted: (_) => _notesFocus.requestFocus(),
                decoration: contractGlassFieldDecoration(
                  context,
                  hintText: 'Precio',
                ),
              ),
            ),
            _CatalogInlineFieldCell(
              width: _kPriceStatusW,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Switch(
                  value: _isActive,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ),
            ),
            _CatalogInlineFieldCell(
              width: _kPriceNotesW,
              child: TextField(
                controller: _notesC,
                focusNode: _notesFocus,
                onSubmitted: (_) => _submit(),
                decoration: contractGlassFieldDecoration(
                  context,
                  hintText: 'Notas',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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

class _CatalogDropdownField<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final FocusNode focusNode;
  final FocusNode? previousFocusNode;
  final FocusNode? nextFocusNode;
  final String? hint;
  final String? title;
  final String Function(T value)? labelBuilder;
  final VoidCallback? onDown;

  const _CatalogDropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.focusNode,
    this.previousFocusNode,
    this.nextFocusNode,
    this.hint,
    this.title,
    this.labelBuilder,
    this.onDown,
  });

  Future<void> _openPicker(BuildContext context) async {
    final selected = await _showMayoreoSingleSelectDialog<T>(
      context,
      title: title ?? hint ?? 'Seleccionar',
      initialValue: value,
      options: items
          .map(
            (item) => _MayoreoPickerOption<T>(
              value: item,
              label: labelBuilder == null
                  ? item.toString()
                  : labelBuilder!(item),
            ),
          )
          .toList(growable: false),
    );
    onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final label = value == null
        ? (hint ?? 'Seleccionar')
        : (labelBuilder == null ? value.toString() : labelBuilder!(value as T));
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            previousFocusNode != null) {
          previousFocusNode!.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
            nextFocusNode != null) {
          nextFocusNode!.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
            onDown != null) {
          onDown!();
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
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openPicker(context),
        child: InputDecorator(
          isFocused: focusNode.hasFocus,
          isEmpty: value == null,
          decoration: contractGlassFieldDecoration(context, hintText: null),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: value == null ? kMayoreoMutedInk : kMayoreoInk,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MayoreoPickerOption<T> {
  final T value;
  final String label;

  const _MayoreoPickerOption({required this.value, required this.label});
}

Future<T?> _showMayoreoSingleSelectDialog<T>(
  BuildContext context, {
  required String title,
  required List<_MayoreoPickerOption<T>> options,
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
      String query = '';
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
              .where(
                (option) =>
                    option.label.toLowerCase().contains(query.toLowerCase()),
              )
              .toList(growable: false);
          syncNodes(filtered.length);
          return AreaThemeScope(
            tokens: mayoreoAreaTokens,
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
                            color: mayoreoAreaTokens.primaryStrong,
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
                            onChanged: (value) =>
                                setLocalState(() => query = value),
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
                                  color: mayoreoAreaTokens.primaryStrong,
                                ),
                              ),
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
                                    final selected =
                                        option.value == initialValue;
                                    final highlighted = focusedIndex == i;
                                    return Focus(
                                      focusNode: itemFocusNodes[i],
                                      onFocusChange: (hasFocus) {
                                        if (hasFocus) {
                                          setLocalState(() => focusedIndex = i);
                                        } else if (focusedIndex == i) {
                                          setLocalState(
                                            () => focusedIndex = null,
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
                                          ).pop(option.value);
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.ignored;
                                      },
                                      child: _MayoreoPickerOptionTile(
                                        label: option.label,
                                        selected: selected,
                                        highlighted: highlighted,
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
            ),
          );
        },
      );
    },
  );
}

Future<Set<T>?> _showMayoreoMultiSelectDialog<T>(
  BuildContext context, {
  required String title,
  required List<_MayoreoPickerOption<T>> options,
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
      String query = '';
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
              .where(
                (option) =>
                    option.label.toLowerCase().contains(query.toLowerCase()),
              )
              .toList(growable: false);
          syncNodes(filtered.length);
          return AreaThemeScope(
            tokens: mayoreoAreaTokens,
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
                            color: mayoreoAreaTokens.primaryStrong,
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
                            onChanged: (value) =>
                                setLocalState(() => query = value),
                          ),
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
                                    final highlighted = focusedIndex == i;
                                    return Focus(
                                      focusNode: itemFocusNodes[i],
                                      onFocusChange: (hasFocus) {
                                        if (hasFocus) {
                                          setLocalState(() => focusedIndex = i);
                                        } else if (focusedIndex == i) {
                                          setLocalState(
                                            () => focusedIndex = null,
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
                                              selected.remove(option.value);
                                            } else {
                                              selected.add(option.value);
                                            }
                                          });
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.ignored;
                                      },
                                      child: _MayoreoPickerOptionTile(
                                        label: option.label,
                                        selected: checked,
                                        highlighted: highlighted,
                                        onTap: () => setLocalState(() {
                                          if (checked) {
                                            selected.remove(option.value);
                                          } else {
                                            selected.add(option.value);
                                          }
                                        }),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonal(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(selected),
                            child: const Text('Aplicar'),
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

class _MayoreoPickerOptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  const _MayoreoPickerOptionTile({
    required this.label,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? mayoreoAreaTokens.badgeBackground.withValues(alpha: 0.90)
        : highlighted
        ? mayoreoAreaTokens.surfaceTint.withValues(alpha: 0.66)
        : Colors.white.withValues(alpha: 0.44);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: kMayoreoInk,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: mayoreoAreaTokens.primaryStrong,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MayoreoCatalogBackground extends StatelessWidget {
  const _MayoreoCatalogBackground();

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
                const Color(0xFFFFF1B8),
                tokens.accent.withValues(alpha: 0.34),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: -260,
          top: -130,
          child: _backgroundCircle(
            760,
            LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.88),
                const Color(0xFFFFED9C),
              ],
            ),
          ),
        ),
        Positioned(
          right: -180,
          top: -70,
          child: _backgroundCircle(
            580,
            LinearGradient(
              colors: [
                const Color(0xFFFFE94A).withValues(alpha: 0.78),
                const Color(0xFFF9A411).withValues(alpha: 0.18),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          bottom: -260,
          child: _backgroundCircle(
            640,
            LinearGradient(
              colors: [
                const Color(0xFFF88C12).withValues(alpha: 0.22),
                tokens.primarySoft.withValues(alpha: 0.88),
              ],
            ),
          ),
        ),
        Positioned(
          right: -105,
          bottom: -120,
          child: IgnorePointer(
            child: Container(
              width: 320,
              height: 500,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(220),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFFE900).withValues(alpha: 0.90),
                    const Color(0xFFF5A10C).withValues(alpha: 0.86),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _backgroundCircle(double diameter, Gradient gradient) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              blurRadius: diameter * 0.10,
              spreadRadius: diameter * 0.015,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: SizedBox(width: diameter, height: diameter),
      ),
    );
  }
}

class _MayoreoCatalogHeaderBrand extends StatelessWidget {
  const _MayoreoCatalogHeaderBrand();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.44)),
            boxShadow: [
              BoxShadow(
                color: tokens.primaryStrong.withValues(alpha: 0.16),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(child: DicsaLogoD(size: 40, progress: 1)),
        ),
        const SizedBox(width: 10),
        Container(
          width: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: tokens.primaryStrong.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Catálogo',
          maxLines: 1,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.25,
            height: 1.0,
            color: tokens.primaryStrong,
          ),
        ),
      ],
    );
  }
}

class _MayoreoCatalogSidePanel extends StatelessWidget {
  final bool canReturnToDirection;
  final ValueChanged<String> onNavigate;

  const _MayoreoCatalogSidePanel({
    required this.canReturnToDirection,
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
                'Mayoreo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              if (canReturnToDirection) ...[
                _MayoreoCatalogNavItem(
                  icon: Icons.arrow_back_rounded,
                  title: 'Volver a Dirección',
                  onTap: () async => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 10),
              ],
              const _MayoreoCatalogSectionHeader(label: 'MENU'),
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
                    _MayoreoCatalogNavItem(
                      icon: Icons.point_of_sale_rounded,
                      title: 'Ventas',
                      subtitle: 'Pedidos y cierre comercial',
                      onTap: () async => onNavigate('Ventas Mayoreo'),
                    ),
                    const SizedBox(height: 8),
                    _MayoreoCatalogNavItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Cuentas',
                      subtitle: 'Factura, cheque y cobranza',
                      onTap: () async => onNavigate('Cuentas'),
                    ),
                    const SizedBox(height: 8),
                    _MayoreoCatalogNavItem(
                      icon: Icons.currency_exchange_rounded,
                      title: 'Cuenta El Palomar',
                      subtitle: 'Cuenta corriente especial',
                      onTap: () async => onNavigate('Cuenta El Palomar'),
                    ),
                    const SizedBox(height: 8),
                    _MayoreoCatalogNavItem(
                      icon: Icons.price_check_rounded,
                      title: 'Catálogo',
                      subtitle: 'Clientes, materiales y precios',
                      accented: true,
                      onTap: () async {},
                    ),
                    const SizedBox(height: 8),
                    _MayoreoCatalogNavItem(
                      icon: Icons.request_quote_rounded,
                      title: 'Ajuste de precios',
                      subtitle: 'Vigentes e historial',
                      onTap: () async => onNavigate('Ajuste de precios'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _MayoreoCatalogSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              if (canReturnToDirection) ...[
                _MayoreoCatalogNavItem(
                  icon: Icons.assessment_outlined,
                  title: 'Dashboard Dirección',
                  subtitle: 'Vista ejecutiva multiarea',
                  onTap: () async => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 8),
              ],
              _MayoreoCatalogNavItem(
                icon: Icons.space_dashboard_rounded,
                title: 'Dashboard Mayoreo',
                subtitle: 'Vista general del área',
                onTap: () async => onNavigate('Dashboard Mayoreo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MayoreoCatalogSectionHeader extends StatelessWidget {
  final String label;

  const _MayoreoCatalogSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.4,
        color: tokens.badgeText,
      ),
    );
  }
}

class _MayoreoCatalogNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool accented;
  final Future<void> Function() onTap;

  const _MayoreoCatalogNavItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.accented = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: accented ? kMayoreoPanelGradient : null,
            color: accented ? null : Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accented
                  ? tokens.primaryStrong.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.26),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accented
                      ? tokens.primaryStrong.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accented
                        ? tokens.primaryStrong.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.42),
                  ),
                ),
                child: Icon(icon, size: 18, color: tokens.primaryStrong),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: tokens.primaryStrong,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.badgeText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MayoreoHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _MayoreoHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_MayoreoHeaderButton> createState() => _MayoreoHeaderButtonState();
}

class _MayoreoHeaderButtonState extends State<_MayoreoHeaderButton> {
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
                    Colors.white.withValues(alpha: highlighted ? 0.32 : 0.22),
                    tokens.surfaceTint.withValues(
                      alpha: highlighted ? 0.42 : 0.26,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: highlighted
                      ? Colors.white.withValues(alpha: 0.76)
                      : Colors.white.withValues(alpha: 0.48),
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

class _CatalogFilterSummaryRow extends StatelessWidget {
  final List<String> labels;
  final VoidCallback? onClearAll;

  const _CatalogFilterSummaryRow({required this.labels, this.onClearAll});

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty && onClearAll == null) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: mayoreoAreaTokens.badgeBackground.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: mayoreoAreaTokens.border.withValues(alpha: 0.70),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: kMayoreoInk,
              ),
            ),
          ),
        if (onClearAll != null)
          TextButton.icon(
            onPressed: onClearAll,
            icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
            label: const Text('Limpiar filtros'),
          ),
      ],
    );
  }
}

class _CatalogHeaderRow extends StatelessWidget {
  final List<_CatalogHeaderColumn> columns;
  final double contentWidth;

  const _CatalogHeaderRow({required this.columns, required this.contentWidth});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w800);
    final tokens = AreaThemeScope.of(context);
    return Card(
      elevation: 0,
      color: Colors.black.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth =
                columns.fold<double>(0, (sum, column) => sum + column.width) +
                _kCatalogActionsW;
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
                                          ? tokens.primary
                                          : tokens.badgeBackground,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: column.active
                                            ? tokens.primaryStrong
                                            : tokens.border,
                                      ),
                                    ),
                                    child: Icon(
                                      column.active
                                          ? Icons.filter_alt
                                          : Icons.filter_alt_outlined,
                                      size: 15,
                                      color: column.active
                                          ? Colors.white
                                          : tokens.badgeText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Text(
                                    column.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: textStyle.copyWith(
                                      color: tokens.badgeText,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: _kCatalogActionsW),
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
          color: kMayoreoInk,
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
      color: mayoreoAreaTokens.surfaceTint.withValues(alpha: 0.98),
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.70)),
      ),
      items: [
        for (final item in widget.menuItems)
          PopupMenuItem<_RowMenuAction>(
            value: item,
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: mayoreoAreaTokens.primaryStrong,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kMayoreoInk,
                  ),
                ),
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
      if (!editable) return cellChild;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
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
                          child: Align(
                            alignment: Alignment.topCenter,
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
                                      color: mayoreoAreaTokens.surfaceTint
                                          .withValues(alpha: 0.98),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.70,
                                          ),
                                        ),
                                      ),
                                      onOpened: widget.onSecondarySelection,
                                      onSelected: (item) => item.onTap(),
                                      itemBuilder: (context) => [
                                        for (final item in widget.menuItems)
                                          PopupMenuItem<_RowMenuAction>(
                                            value: item,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  item.icon,
                                                  color: mayoreoAreaTokens
                                                      .primaryStrong,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  item.label,
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: kMayoreoInk,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? tokens.primarySoft.withValues(
                                                  alpha: 0.42,
                                                )
                                              : Colors.white.withValues(
                                                  alpha: 0.88,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: selected
                                                ? tokens.primaryStrong
                                                      .withValues(alpha: 0.36)
                                                : tokens.border.withValues(
                                                    alpha: 0.82,
                                                  ),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                              color: Colors.black.withValues(
                                                alpha: 0.06,
                                              ),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.more_horiz_rounded,
                                            color: tokens.primaryStrong,
                                            size: 20,
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

class _MayoreoCompany {
  final String id;
  final String code;
  final String name;
  final String contact;
  final bool active;
  final String notes;

  const _MayoreoCompany({
    required this.id,
    required this.code,
    required this.name,
    required this.contact,
    this.active = true,
    this.notes = '',
  });

  const _MayoreoCompany.empty()
    : id = '',
      code = '',
      name = '',
      contact = '',
      active = false,
      notes = '';

  _MayoreoCompany copyWith({
    String? code,
    String? name,
    String? contact,
    bool? active,
    String? notes,
  }) {
    return _MayoreoCompany(
      id: id,
      code: code ?? this.code,
      name: name ?? this.name,
      contact: contact ?? this.contact,
      active: active ?? this.active,
      notes: notes ?? this.notes,
    );
  }
}

class _MayoreoMaterial {
  final String id;
  final String code;
  final String level;
  final String name;
  final String unit;
  final String category;
  final String? family;
  final String? generalMaterialId;
  final bool active;
  final String notes;

  const _MayoreoMaterial({
    required this.id,
    required this.code,
    required this.level,
    required this.name,
    required this.unit,
    required this.category,
    this.family,
    this.generalMaterialId,
    this.active = true,
    this.notes = '',
  });

  const _MayoreoMaterial.empty()
    : id = '',
      code = '',
      level = '',
      name = '',
      unit = '',
      category = '',
      family = null,
      generalMaterialId = null,
      active = false,
      notes = '';

  _MayoreoMaterial copyWith({
    String? code,
    String? level,
    String? name,
    String? unit,
    String? category,
    String? family,
    String? generalMaterialId,
    bool clearFamily = false,
    bool clearGeneralMaterialId = false,
    bool? active,
    String? notes,
  }) {
    return _MayoreoMaterial(
      id: id,
      code: code ?? this.code,
      level: level ?? this.level,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      family: clearFamily ? null : (family ?? this.family),
      generalMaterialId: clearGeneralMaterialId
          ? null
          : (generalMaterialId ?? this.generalMaterialId),
      active: active ?? this.active,
      notes: notes ?? this.notes,
    );
  }
}

class _MayoreoPrice {
  final String id;
  final String companyId;
  final String materialId;
  final double amount;
  final bool active;
  final String notes;
  final DateTime? updatedAt;

  const _MayoreoPrice({
    required this.id,
    required this.companyId,
    required this.materialId,
    required this.amount,
    this.active = true,
    this.notes = '',
    this.updatedAt,
  });

  _MayoreoPrice copyWith({
    String? companyId,
    String? materialId,
    double? amount,
    bool? active,
    String? notes,
    DateTime? updatedAt,
  }) {
    return _MayoreoPrice(
      id: id,
      companyId: companyId ?? this.companyId,
      materialId: materialId ?? this.materialId,
      amount: amount ?? this.amount,
      active: active ?? this.active,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
