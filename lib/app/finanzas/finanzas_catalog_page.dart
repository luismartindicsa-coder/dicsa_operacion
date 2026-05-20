import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../compras/compras_dashboard_page.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../mayoreo/mayoreo_sorting.dart';
import '../services/inventory_movements_grid.dart';
import 'finanzas_data_store.dart';
import 'finanzas_dashboard_page.dart';
import 'finanzas_company_directory_page.dart';
import 'finanzas_theme.dart';

class FinanzasCatalogPage extends StatefulWidget {
  final bool instantOpen;

  const FinanzasCatalogPage({super.key, this.instantOpen = false});

  @override
  State<FinanzasCatalogPage> createState() => _FinanzasCatalogPageState();
}

class _FinanzasCatalogPageState extends State<FinanzasCatalogPage> {
  static const double _kFinanceActionsW = 86;
  static const double _kFinanceCompanyNameW = 280;
  static const double _kFinanceCompanySourceW = 150;
  static const double _kFinanceCompanyLinkW = 260;
  static const double _kFinanceCompanyStatusW = 120;
  static const double _kFinanceCompanyNotesW = 360;
  static const double _kFinanceCompanyContentW =
      _kFinanceCompanyNameW +
      _kFinanceCompanySourceW +
      _kFinanceCompanyLinkW +
      _kFinanceCompanyStatusW +
      _kFinanceCompanyNotesW;

  static const double _kFinanceConceptNameW = 250;
  static const double _kFinanceConceptFamilyW = 170;
  static const double _kFinanceConceptDirectionW = 150;
  static const double _kFinanceConceptRulesW = 190;
  static const double _kFinanceConceptStatusW = 120;
  static const double _kFinanceConceptNotesW = 300;
  static const double _kFinanceConceptContentW =
      _kFinanceConceptNameW +
      _kFinanceConceptFamilyW +
      _kFinanceConceptDirectionW +
      _kFinanceConceptRulesW +
      _kFinanceConceptStatusW +
      _kFinanceConceptNotesW;

  static const double _kFinanceRelationCompanyW = 250;
  static const double _kFinanceRelationConceptW = 240;
  static const double _kFinanceRelationModeW = 160;
  static const double _kFinanceRelationStatusW = 120;
  static const double _kFinanceRelationNotesW = 380;
  static const double _kFinanceRelationContentW =
      _kFinanceRelationCompanyW +
      _kFinanceRelationConceptW +
      _kFinanceRelationModeW +
      _kFinanceRelationStatusW +
      _kFinanceRelationNotesW;

  static const List<String> _kFinanceCompanySources = <String>[
    'COMPRAS',
    'DIRECTO',
    'VENTAS',
  ];
  static const List<String> _kFinanceConceptFamilies = <String>[
    'AJUSTE',
    'COBRO',
    'GASTO',
    'OTRO',
    'PAGO',
    'PRESTAMO',
  ];
  static const List<String> _kFinanceDirections = <String>[
    'AMBAS',
    'ENTRADA',
    'SALIDA',
  ];
  static const List<String> _kFinanceRelationModes = <String>[
    'AUTOMATICA',
    'MANUAL',
    'MIXTA',
  ];

  bool _menuOpen = false;
  bool _canReturnToDirection = false;
  int _activeTabIndex = 0;
  final ScrollController _companyRowsScrollController = ScrollController();
  final ScrollController _conceptRowsScrollController = ScrollController();
  final ScrollController _relationRowsScrollController = ScrollController();
  final GlobalKey _companyRowsViewportKey = GlobalKey(
    debugLabel: 'finance_company_rows_viewport',
  );
  final GlobalKey _conceptRowsViewportKey = GlobalKey(
    debugLabel: 'finance_concept_rows_viewport',
  );
  final GlobalKey _relationRowsViewportKey = GlobalKey(
    debugLabel: 'finance_relation_rows_viewport',
  );
  final Map<String, GlobalKey> _rowItemKeys = <String, GlobalKey>{};
  final FocusNode _gridRowsFocusNode = FocusNode(
    debugLabel: 'finance_catalog_grid_rows',
  );
  final TextEditingController _companyNameC = TextEditingController();
  final TextEditingController _companyLinkedNameC = TextEditingController();
  final TextEditingController _companyNotesC = TextEditingController();
  final TextEditingController _conceptNameC = TextEditingController();
  final TextEditingController _conceptNotesC = TextEditingController();
  final TextEditingController _relationNotesC = TextEditingController();
  String _companySource = 'DIRECTO';
  String _conceptFamily = 'GASTO';
  String _conceptDirection = 'SALIDA';
  bool _conceptRequiresCompany = true;
  String? _relationCompanyId;
  String? _relationConceptId;
  String _relationMode = 'MANUAL';
  String? _editingCompanyId;
  String? _editingConceptId;
  String? _editingRelationId;
  bool? _companyActiveFilter;
  Set<String> _companyNameFilters = <String>{};
  Set<String> _companySourceFilters = <String>{};
  bool? _conceptActiveFilter;
  Set<String> _conceptNameFilters = <String>{};
  Set<String> _conceptFamilyFilters = <String>{};
  Set<String> _conceptDirectionFilters = <String>{};
  bool? _relationActiveFilter;
  String? _relationCompanyFilterId;
  String? _relationConceptFilterId;
  Set<String> _relationModeFilters = <String>{};
  String? _selectedRowKey;
  String? _selectionAnchorRowKey;
  final Set<String> _bulkSelectedRowKeys = <String>{};
  bool _dragSelectionActive = false;
  List<String> _dragSelectionKeys = const <String>[];
  String? _dragSelectionAnchorKey;
  Offset? _dragPointerGlobal;
  double _dragAutoScrollVelocity = 0;
  Timer? _dragAutoScrollTimer;
  late List<_FinanceCompany> _companies;
  late List<_FinanceConcept> _concepts;
  late List<_FinanceRelation> _relations;

  @override
  void initState() {
    super.initState();
    _companies = const <_FinanceCompany>[];
    _concepts = const <_FinanceConcept>[];
    _relations = const <_FinanceRelation>[];
    _resolveNavigationAccess();
    unawaited(_loadCatalogSnapshot());
  }

  @override
  void dispose() {
    _companyRowsScrollController.dispose();
    _conceptRowsScrollController.dispose();
    _relationRowsScrollController.dispose();
    _gridRowsFocusNode.dispose();
    _dragAutoScrollTimer?.cancel();
    _companyNameC.dispose();
    _companyLinkedNameC.dispose();
    _companyNotesC.dispose();
    _conceptNameC.dispose();
    _conceptNotesC.dispose();
    _relationNotesC.dispose();
    super.dispose();
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
    });
  }

  Future<void> _logout() async {
    await signOutAndRouteToLogin(context);
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openFinanzasDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openComprasDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const ComprasDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openFinanzasDirectory() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasCompanyDirectoryPage(instantOpen: true)),
    );
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Dirección':
        unawaited(_openDirectionDashboard());
        return;
      case 'Dashboard Finanzas':
        unawaited(_openFinanzasDashboard());
        return;
      case 'Dashboard Compras':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openComprasDashboard());
        return;
      case 'Catálogo Finanzas':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      case 'Directorio Empresas':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openFinanzasDirectory());
        return;
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _loadCatalogSnapshot() async {
    try {
      final snapshot = await FinanzasDataStore.loadCatalogSnapshot();
      if (!mounted) return;
      setState(() {
        _companies = snapshot.companies
            .map(
              (row) => _FinanceCompany(
                id: row.id,
                name: row.name,
                source: row.source,
                linkedName: row.linkedName,
                active: row.active,
                notes: row.notes,
              ),
            )
            .toList(growable: false);
        _concepts = snapshot.concepts
            .map(
              (row) => _FinanceConcept(
                id: row.id,
                name: row.name,
                family: row.family,
                direction: row.direction,
                requiresCompany: row.requiresCompany,
                active: row.active,
                notes: row.notes,
              ),
            )
            .toList(growable: false);
        _relations = snapshot.relations
            .map(
              (row) => _FinanceRelation(
                id: row.id,
                companyId: row.companyId,
                conceptId: row.conceptId,
                mode: row.mode,
                active: row.active,
                notes: row.notes,
              ),
            )
            .toList(growable: false);
      });
    } catch (_) {
      if (mounted) {
        _toast('No se pudo cargar Catálogo Finanzas.');
      }
    }
  }

  Future<void> _persistCatalogSnapshot() async {
    final snapshot = FinanzasCatalogSnapshot(
      companies: _companies
          .map(
            (row) => FinanzasCatalogCompanyRecord(
              id: row.id,
              name: row.name,
              source: row.source,
              linkedName: row.linkedName,
              active: row.active,
              notes: row.notes,
            ),
          )
          .toList(growable: false),
      concepts: _concepts
          .map(
            (row) => FinanzasCatalogConceptRecord(
              id: row.id,
              name: row.name,
              family: row.family,
              direction: row.direction,
              requiresCompany: row.requiresCompany,
              active: row.active,
              notes: row.notes,
            ),
          )
          .toList(growable: false),
      relations: _relations
          .map(
            (row) => FinanzasCatalogRelationRecord(
              id: row.id,
              companyId: row.companyId,
              conceptId: row.conceptId,
              mode: row.mode,
              active: row.active,
              notes: row.notes,
            ),
          )
          .toList(growable: false),
    );
    try {
      await FinanzasDataStore.saveCatalogSnapshot(snapshot);
    } catch (_) {
      if (mounted) {
        _toast(
          'No se pudo guardar Catálogo Finanzas. Se restauró el estado remoto.',
        );
      }
      await _loadCatalogSnapshot();
    }
  }

  Future<void> _saveCompany() async {
    final name = _normalizeFinanceText(_companyNameC.text);
    final linkedName = _normalizeFinanceText(_companyLinkedNameC.text);
    if (name.isEmpty) {
      _toast('Empresa es obligatoria');
      return;
    }
    final duplicated = _companies.any((row) => row.name == name);
    if (duplicated) {
      _toast('La empresa ya existe en Finanzas');
      return;
    }
    setState(() {
      _companies = <_FinanceCompany>[
        _FinanceCompany(
          id: _financeId('fc'),
          name: name,
          source: _companySource,
          linkedName: linkedName,
          active: true,
          notes: _companyNotesC.text.trim(),
        ),
        ..._companies,
      ];
      _setSingleSelection('fc:${_companies.first.id}');
      _companyNameC.clear();
      _companyLinkedNameC.clear();
      _companyNotesC.clear();
      _companySource = 'DIRECTO';
    });
    await _persistCatalogSnapshot();
  }

  Future<void> _saveConcept() async {
    final name = _normalizeFinanceText(_conceptNameC.text);
    if (name.isEmpty) {
      _toast('Concepto es obligatorio');
      return;
    }
    final duplicated = _concepts.any((row) => row.name == name);
    if (duplicated) {
      _toast('El concepto ya existe en Finanzas');
      return;
    }
    setState(() {
      final concept = _FinanceConcept(
        id: _financeId('fn'),
        name: name,
        family: _conceptFamily,
        direction: _conceptDirection,
        requiresCompany: _conceptRequiresCompany,
        active: true,
        notes: _conceptNotesC.text.trim(),
      );
      _concepts = <_FinanceConcept>[concept, ..._concepts];
      _setSingleSelection('fn:${concept.id}');
      _conceptNameC.clear();
      _conceptNotesC.clear();
      _conceptFamily = 'GASTO';
      _conceptDirection = 'SALIDA';
      _conceptRequiresCompany = true;
    });
    await _persistCatalogSnapshot();
  }

  Future<void> _saveRelation() async {
    if (_relationCompanyId == null || _relationConceptId == null) {
      _toast('Empresa y concepto son obligatorios');
      return;
    }
    final duplicated = _relations.any(
      (row) =>
          row.companyId == _relationCompanyId &&
          row.conceptId == _relationConceptId,
    );
    if (duplicated) {
      _toast('La relación empresa + concepto ya existe');
      return;
    }
    setState(() {
      final relation = _FinanceRelation(
        id: _financeId('fr'),
        companyId: _relationCompanyId!,
        conceptId: _relationConceptId!,
        mode: _relationMode,
        active: true,
        notes: _relationNotesC.text.trim(),
      );
      _relations = <_FinanceRelation>[relation, ..._relations];
      _setSingleSelection('fr:${relation.id}');
      _relationCompanyId = null;
      _relationConceptId = null;
      _relationMode = 'MANUAL';
      _relationNotesC.clear();
    });
    await _persistCatalogSnapshot();
  }

  Future<void> _toggleCompanyActive(_FinanceCompany row) async {
    setState(() {
      _companies = _companies
          .map(
            (item) =>
                item.id == row.id ? item.copyWith(active: !item.active) : item,
          )
          .toList(growable: false);
    });
    await _persistCatalogSnapshot();
  }

  Future<void> _toggleConceptActive(_FinanceConcept row) async {
    setState(() {
      _concepts = _concepts
          .map(
            (item) =>
                item.id == row.id ? item.copyWith(active: !item.active) : item,
          )
          .toList(growable: false);
    });
    await _persistCatalogSnapshot();
  }

  Future<void> _toggleRelationActive(_FinanceRelation row) async {
    setState(() {
      _relations = _relations
          .map(
            (item) =>
                item.id == row.id ? item.copyWith(active: !item.active) : item,
          )
          .toList(growable: false);
    });
    await _persistCatalogSnapshot();
  }

  Future<void> _deleteCompany(_FinanceCompany row) async {
    final relationInUse = _relations.any((item) => item.companyId == row.id);
    if (relationInUse) {
      _toast('No puedes eliminar una empresa usada en relaciones');
      return;
    }
    setState(() {
      _companies = _companies
          .where((item) => item.id != row.id)
          .toList(growable: false);
      _removeSelectionKey('fc:${row.id}');
    });
    await _persistCatalogSnapshot();
  }

  Future<void> _deleteConcept(_FinanceConcept row) async {
    final relationInUse = _relations.any((item) => item.conceptId == row.id);
    if (relationInUse) {
      _toast('No puedes eliminar un concepto usado en relaciones');
      return;
    }
    setState(() {
      _concepts = _concepts
          .where((item) => item.id != row.id)
          .toList(growable: false);
      _removeSelectionKey('fn:${row.id}');
    });
    await _persistCatalogSnapshot();
  }

  Future<void> _deleteRelation(_FinanceRelation row) async {
    setState(() {
      _relations = _relations
          .where((item) => item.id != row.id)
          .toList(growable: false);
      _removeSelectionKey('fr:${row.id}');
    });
    await _persistCatalogSnapshot();
  }

  String _companyNameById(String id) {
    return _companies
        .firstWhere(
          (row) => row.id == id,
          orElse: () => const _FinanceCompany.empty(),
        )
        .name;
  }

  String _conceptNameById(String id) {
    return _concepts
        .firstWhere(
          (row) => row.id == id,
          orElse: () => const _FinanceConcept.empty(),
        )
        .name;
  }

  Future<void> _toggleSelectedActive() async {
    if (_bulkSelectedRowKeys.isEmpty) return;
    final keys = Set<String>.from(_bulkSelectedRowKeys);
    setState(() {
      switch (_activeTabIndex) {
        case 0:
          _companies = _companies
              .map(
                (row) => keys.contains('fc:${row.id}')
                    ? row.copyWith(active: !row.active)
                    : row,
              )
              .toList(growable: false);
          break;
        case 1:
          _concepts = _concepts
              .map(
                (row) => keys.contains('fn:${row.id}')
                    ? row.copyWith(active: !row.active)
                    : row,
              )
              .toList(growable: false);
          break;
        default:
          _relations = _relations
              .map(
                (row) => keys.contains('fr:${row.id}')
                    ? row.copyWith(active: !row.active)
                    : row,
              )
              .toList(growable: false);
      }
    });
    await _persistCatalogSnapshot();
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
          onDeleteSelection: () async => _toggleSelectedActive(),
        );
      case 1:
        return InventoryGridTopBarData(
          metricIcon: Icons.label_important_outline_rounded,
          metricLabel: 'CONCEPTOS',
          metricValue: '${_visibleConcepts.length}',
          metricSubtitle: 'Filtrado (${_visibleConcepts.length} registros)',
          exportingCsv: false,
          gridEditMode: false,
          canToggleGridEdit: false,
          canDeleteSelection: _selectedCount > 0,
          deletingSelection: false,
          selectedCount: _selectedCount,
          onDeleteSelection: () async => _toggleSelectedActive(),
        );
      default:
        return InventoryGridTopBarData(
          metricIcon: Icons.account_tree_outlined,
          metricLabel: 'RELACIONES',
          metricValue: '${_visibleRelations.length}',
          metricSubtitle: 'Filtrado (${_visibleRelations.length} registros)',
          exportingCsv: false,
          gridEditMode: false,
          canToggleGridEdit: false,
          canDeleteSelection: _selectedCount > 0,
          deletingSelection: false,
          selectedCount: _selectedCount,
          onDeleteSelection: () async => _toggleSelectedActive(),
        );
    }
  }

  KeyEventResult _handleGridKeyEvent(KeyEvent event, List<String> visibleKeys) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_isEditableTextFocused()) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_menuOpen) {
        setState(() => _menuOpen = false);
        return KeyEventResult.handled;
      }
      if (_editingCompanyId != null) {
        _cancelCompanyInlineEdit();
        return KeyEventResult.handled;
      }
      if (_editingConceptId != null) {
        _cancelConceptInlineEdit();
        return KeyEventResult.handled;
      }
      if (_editingRelationId != null) {
        _cancelRelationInlineEdit();
        return KeyEventResult.handled;
      }
      if (_bulkSelectedRowKeys.isNotEmpty) {
        setState(_clearSelection);
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_selectedRowKey == null) return KeyEventResult.handled;
      setState(() {
        switch (_activeTabIndex) {
          case 0:
            _editingCompanyId = _selectedRowKey!.split(':').last;
            break;
          case 1:
            _editingConceptId = _selectedRowKey!.split(':').last;
            break;
          default:
            _editingRelationId = _selectedRowKey!.split(':').last;
        }
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      if (_selectedCount == 0 || !_gridRowsFocusNode.hasPrimaryFocus) {
        return KeyEventResult.ignored;
      }
      unawaited(_toggleSelectedActive());
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureRowVisible(target);
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      final target =
          visibleKeys[(currentIndex - 1).clamp(0, visibleKeys.length - 1)];
      setState(() {
        if (_isShiftPressed()) {
          _selectRange(target, visibleKeys);
        } else {
          _setSingleSelection(target);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureRowVisible(target);
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<_FinanceCompany> get _visibleCompanies {
    return _companies
        .where((row) {
          if (_companyNameFilters.isNotEmpty &&
              !_companyNameFilters.contains(row.name)) {
            return false;
          }
          if (_companySourceFilters.isNotEmpty &&
              !_companySourceFilters.contains(row.source)) {
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

  List<_FinanceConcept> get _visibleConcepts {
    return _concepts
        .where((row) {
          if (_conceptNameFilters.isNotEmpty &&
              !_conceptNameFilters.contains(row.name)) {
            return false;
          }
          if (_conceptFamilyFilters.isNotEmpty &&
              !_conceptFamilyFilters.contains(row.family)) {
            return false;
          }
          if (_conceptDirectionFilters.isNotEmpty &&
              !_conceptDirectionFilters.contains(row.direction)) {
            return false;
          }
          if (_conceptActiveFilter != null &&
              row.active != _conceptActiveFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<_FinanceRelation> get _visibleRelations {
    return _relations
        .where((row) {
          if (_relationCompanyFilterId != null &&
              row.companyId != _relationCompanyFilterId) {
            return false;
          }
          if (_relationConceptFilterId != null &&
              row.conceptId != _relationConceptFilterId) {
            return false;
          }
          if (_relationModeFilters.isNotEmpty &&
              !_relationModeFilters.contains(row.mode)) {
            return false;
          }
          if (_relationActiveFilter != null &&
              row.active != _relationActiveFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<String> _currentVisibleRowKeys() {
    switch (_activeTabIndex) {
      case 0:
        return _visibleCompanies
            .map((item) => 'fc:${item.id}')
            .toList(growable: false);
      case 1:
        return _visibleConcepts
            .map((item) => 'fn:${item.id}')
            .toList(growable: false);
      default:
        return _visibleRelations
            .map((item) => 'fr:${item.id}')
            .toList(growable: false);
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

  void _focusGridRows() {
    final rowKeys = _currentVisibleRowKeys();
    if (rowKeys.isEmpty) return;
    _gridRowsFocusNode.requestFocus();
    if (_selectedRowKey != null) return;
    setState(() => _setSingleSelection(rowKeys.first));
  }

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureRowVisible(rowKey);
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
      _dragPointerGlobal = null;
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
      _dragPointerGlobal = null;
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
    });
  }

  bool _isRowSelected(String rowKey) => _bulkSelectedRowKeys.contains(rowKey);

  int get _selectedCount => _bulkSelectedRowKeys.length;

  ScrollController get _activeRowsScrollController {
    switch (_activeTabIndex) {
      case 0:
        return _companyRowsScrollController;
      case 1:
        return _conceptRowsScrollController;
      default:
        return _relationRowsScrollController;
    }
  }

  GlobalKey get _activeRowsViewportKey {
    switch (_activeTabIndex) {
      case 0:
        return _companyRowsViewportKey;
      case 1:
        return _conceptRowsViewportKey;
      default:
        return _relationRowsViewportKey;
    }
  }

  GlobalKey _rowItemKey(String rowKey) {
    return _rowItemKeys.putIfAbsent(
      rowKey,
      () => GlobalKey(debugLabel: 'finance_catalog_row_$rowKey'),
    );
  }

  void _ensureRowVisible(String rowKey) {
    final rowContext = _rowItemKey(rowKey).currentContext;
    if (rowContext == null) return;
    Scrollable.ensureVisible(
      rowContext,
      alignment: 0.45,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  int? _visibleRowIndexAtGlobalPosition(
    Offset globalPosition,
    List<String> visibleKeys,
  ) {
    for (var i = 0; i < visibleKeys.length; i++) {
      final box =
          _rowItemKey(visibleKeys[i]).currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final topLeft = box.localToGlobal(Offset.zero);
      final rect = topLeft & box.size;
      if (rect.contains(globalPosition)) return i;
    }
    return null;
  }

  int? _mountedEdgeRowIndex(List<String> visibleKeys, {required bool last}) {
    final indexes = <int>[];
    for (var i = 0; i < visibleKeys.length; i++) {
      final box =
          _rowItemKey(visibleKeys[i]).currentContext?.findRenderObject()
              as RenderBox?;
      if (box != null && box.hasSize) {
        indexes.add(i);
      }
    }
    if (indexes.isEmpty) return null;
    return last ? indexes.last : indexes.first;
  }

  void _handleRowsPointerMove(
    PointerMoveEvent event,
    List<String> visibleKeys,
  ) {
    if (!_dragSelectionActive) return;
    _dragPointerGlobal = event.position;
    _updateDragAutoScroll(visibleKeys);
    final visibleIndex = _visibleRowIndexAtGlobalPosition(
      event.position,
      visibleKeys,
    );
    if (visibleIndex == null) return;
    _updateDragSelection(visibleKeys[visibleIndex]);
  }

  void _updateDragAutoScroll(List<String> visibleKeys) {
    if (!_dragSelectionActive || _dragPointerGlobal == null) {
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    final box =
        _activeRowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _dragAutoScrollVelocity = 0;
      _dragAutoScrollTimer?.cancel();
      _dragAutoScrollTimer = null;
      return;
    }
    const edge = 36.0;
    const maxStep = 18.0;
    final local = box.globalToLocal(_dragPointerGlobal!);
    final y = local.dy;
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
      (_) => _performDragAutoScroll(visibleKeys),
    );
  }

  void _performDragAutoScroll(List<String> visibleKeys) {
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
    if ((next - position.pixels).abs() < 0.5) return;
    _activeRowsScrollController.jumpTo(next);
    final pointer = _dragPointerGlobal;
    final viewportBox =
        _activeRowsViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (pointer == null || viewportBox == null || !viewportBox.hasSize) return;
    final visibleIndex = _visibleRowIndexAtGlobalPosition(pointer, visibleKeys);
    int? targetIndex = visibleIndex;
    if (targetIndex == null) {
      final local = viewportBox.globalToLocal(pointer);
      if (local.dy < 0) {
        targetIndex = _mountedEdgeRowIndex(visibleKeys, last: false);
      } else if (local.dy > viewportBox.size.height) {
        targetIndex = _mountedEdgeRowIndex(visibleKeys, last: true);
      }
    }
    if (targetIndex == null) return;
    _updateDragSelection(visibleKeys[targetIndex]);
  }

  void _cancelCompanyInlineEdit() => setState(() => _editingCompanyId = null);
  void _cancelConceptInlineEdit() => setState(() => _editingConceptId = null);
  void _cancelRelationInlineEdit() => setState(() => _editingRelationId = null);

  Future<void> _pickCompanyNameFilter() async {
    final selected = await _showFinanceMultiSelectDialog<String>(
      context,
      title: 'Seleccionar empresa',
      initialValues: _companyNameFilters,
      options: _companies
          .map(
            (row) =>
                _FinancePickerOption<String>(value: row.name, label: row.name),
          )
          .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() => _companyNameFilters = selected);
  }

  Future<void> _pickCompanySourceFilter() async {
    final selected = await _showFinanceMultiSelectDialog<String>(
      context,
      title: 'Seleccionar origen',
      initialValues: _companySourceFilters,
      options: _kFinanceCompanySources
          .map((row) => _FinancePickerOption<String>(value: row, label: row))
          .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() => _companySourceFilters = selected);
  }

  Future<void> _pickCompanyActiveFilter() async {
    final value = await _showFinanceSingleSelectDialog<bool?>(
      context,
      title: 'Estatus de empresa',
      initialValue: _companyActiveFilter,
      options: const [
        _FinancePickerOption<bool?>(value: true, label: 'ACTIVO'),
        _FinancePickerOption<bool?>(value: false, label: 'INACTIVO'),
      ],
      allowClear: true,
    );
    if (!mounted) return;
    setState(() => _companyActiveFilter = value);
  }

  Future<void> _pickConceptNameFilter() async {
    final selected = await _showFinanceMultiSelectDialog<String>(
      context,
      title: 'Seleccionar concepto',
      initialValues: _conceptNameFilters,
      options: _concepts
          .map(
            (row) =>
                _FinancePickerOption<String>(value: row.name, label: row.name),
          )
          .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() => _conceptNameFilters = selected);
  }

  Future<void> _pickConceptFamilyFilter() async {
    final selected = await _showFinanceMultiSelectDialog<String>(
      context,
      title: 'Seleccionar familia',
      initialValues: _conceptFamilyFilters,
      options: _kFinanceConceptFamilies
          .map((row) => _FinancePickerOption<String>(value: row, label: row))
          .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() => _conceptFamilyFilters = selected);
  }

  Future<void> _pickConceptDirectionFilter() async {
    final selected = await _showFinanceMultiSelectDialog<String>(
      context,
      title: 'Seleccionar direccion',
      initialValues: _conceptDirectionFilters,
      options: _kFinanceDirections
          .map((row) => _FinancePickerOption<String>(value: row, label: row))
          .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() => _conceptDirectionFilters = selected);
  }

  Future<void> _pickConceptActiveFilter() async {
    final value = await _showFinanceSingleSelectDialog<bool?>(
      context,
      title: 'Estatus de concepto',
      initialValue: _conceptActiveFilter,
      options: const [
        _FinancePickerOption<bool?>(value: true, label: 'ACTIVO'),
        _FinancePickerOption<bool?>(value: false, label: 'INACTIVO'),
      ],
      allowClear: true,
    );
    if (!mounted) return;
    setState(() => _conceptActiveFilter = value);
  }

  Future<void> _pickRelationCompanyFilter() async {
    final value = await _showFinanceSingleSelectDialog<String?>(
      context,
      title: 'Seleccionar empresa',
      initialValue: _relationCompanyFilterId,
      options: _companies
          .map(
            (row) =>
                _FinancePickerOption<String?>(value: row.id, label: row.name),
          )
          .toList(growable: false),
      allowClear: true,
    );
    if (!mounted) return;
    setState(() => _relationCompanyFilterId = value);
  }

  Future<void> _pickRelationConceptFilter() async {
    final value = await _showFinanceSingleSelectDialog<String?>(
      context,
      title: 'Seleccionar concepto',
      initialValue: _relationConceptFilterId,
      options: _concepts
          .map(
            (row) =>
                _FinancePickerOption<String?>(value: row.id, label: row.name),
          )
          .toList(growable: false),
      allowClear: true,
    );
    if (!mounted) return;
    setState(() => _relationConceptFilterId = value);
  }

  Future<void> _pickRelationModeFilter() async {
    final selected = await _showFinanceMultiSelectDialog<String>(
      context,
      title: 'Seleccionar modo',
      initialValues: _relationModeFilters,
      options: _kFinanceRelationModes
          .map((row) => _FinancePickerOption<String>(value: row, label: row))
          .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() => _relationModeFilters = selected);
  }

  Future<void> _pickRelationActiveFilter() async {
    final value = await _showFinanceSingleSelectDialog<bool?>(
      context,
      title: 'Estatus de relacion',
      initialValue: _relationActiveFilter,
      options: const [
        _FinancePickerOption<bool?>(value: true, label: 'ACTIVO'),
        _FinancePickerOption<bool?>(value: false, label: 'INACTIVO'),
      ],
      allowClear: true,
    );
    if (!mounted) return;
    setState(() => _relationActiveFilter = value);
  }

  Future<void> _saveCompanyInline(
    _FinanceCompany row,
    Map<String, dynamic> payload,
  ) async {
    final name = _normalizeFinanceText((payload['name'] as String?) ?? '');
    final linkedName = _normalizeFinanceText(
      (payload['linkedName'] as String?) ?? '',
    );
    if (name.isEmpty) {
      _toast('Empresa es obligatoria');
      return;
    }
    final duplicated = _companies.any(
      (item) => item.id != row.id && item.name == name,
    );
    if (duplicated) {
      _toast('La empresa ya existe en Finanzas');
      return;
    }
    setState(() {
      _companies = _companies
          .map(
            (item) => item.id == row.id
                ? item.copyWith(
                    name: name,
                    source: payload['source'] as String? ?? item.source,
                    linkedName: linkedName,
                    active: payload['active'] as bool? ?? item.active,
                    notes: (payload['notes'] as String? ?? '').trim(),
                  )
                : item,
          )
          .toList(growable: false);
      _editingCompanyId = null;
      _setSingleSelection('fc:${row.id}');
    });
    await _persistCatalogSnapshot();
    _focusGridRows();
  }

  Future<void> _saveConceptInline(
    _FinanceConcept row,
    Map<String, dynamic> payload,
  ) async {
    final name = _normalizeFinanceText((payload['name'] as String?) ?? '');
    if (name.isEmpty) {
      _toast('Concepto es obligatorio');
      return;
    }
    final duplicated = _concepts.any(
      (item) => item.id != row.id && item.name == name,
    );
    if (duplicated) {
      _toast('El concepto ya existe en Finanzas');
      return;
    }
    setState(() {
      _concepts = _concepts
          .map(
            (item) => item.id == row.id
                ? item.copyWith(
                    name: name,
                    family: payload['family'] as String? ?? item.family,
                    direction:
                        payload['direction'] as String? ?? item.direction,
                    requiresCompany:
                        payload['requiresCompany'] as bool? ??
                        item.requiresCompany,
                    active: payload['active'] as bool? ?? item.active,
                    notes: (payload['notes'] as String? ?? '').trim(),
                  )
                : item,
          )
          .toList(growable: false);
      _editingConceptId = null;
      _setSingleSelection('fn:${row.id}');
    });
    await _persistCatalogSnapshot();
    _focusGridRows();
  }

  Future<void> _saveRelationInline(
    _FinanceRelation row,
    Map<String, dynamic> payload,
  ) async {
    final companyId = payload['companyId'] as String?;
    final conceptId = payload['conceptId'] as String?;
    if (companyId == null || conceptId == null) {
      _toast('Empresa y concepto son obligatorios');
      return;
    }
    final duplicated = _relations.any(
      (item) =>
          item.id != row.id &&
          item.companyId == companyId &&
          item.conceptId == conceptId,
    );
    if (duplicated) {
      _toast('La relación empresa + concepto ya existe');
      return;
    }
    setState(() {
      _relations = _relations
          .map(
            (item) => item.id == row.id
                ? item.copyWith(
                    companyId: companyId,
                    conceptId: conceptId,
                    mode: payload['mode'] as String? ?? item.mode,
                    active: payload['active'] as bool? ?? item.active,
                    notes: (payload['notes'] as String? ?? '').trim(),
                  )
                : item,
          )
          .toList(growable: false);
      _editingRelationId = null;
      _setSingleSelection('fr:${row.id}');
    });
    await _persistCatalogSnapshot();
    _focusGridRows();
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: finanzasAreaTokens,
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
          background: const _FinanzasCatalogBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => _FinanzasHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => const _FinanzasCatalogHeaderBrand(),
          trailingBuilder: (_, _) => _FinanzasHeaderButton(
            label: 'Cerrar sesión',
            icon: Icons.logout_rounded,
            onTap: _logout,
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
                  child: _FinanzasCatalogSidePanel(
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
    final rowKeys = _currentVisibleRowKeys();
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
                if (_editingCompanyId != null ||
                    _editingConceptId != null ||
                    _editingRelationId != null ||
                    _bulkSelectedRowKeys.isNotEmpty) {
                  setState(() {
                    _editingCompanyId = null;
                    _editingConceptId = null;
                    _editingRelationId = null;
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
                            setState(() => _activeTabIndex = controller.index);
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
                              maxWidth: 920,
                              showBottomRail: false,
                              items: const [
                                AppFolderTabItem(
                                  label: 'Empresas',
                                  icon: Icons.business_center_rounded,
                                ),
                                AppFolderTabItem(
                                  label: 'Conceptos',
                                  icon: Icons.label_important_outline_rounded,
                                ),
                                AppFolderTabItem(
                                  label: 'Relaciones',
                                  icon: Icons.account_tree_outlined,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: TabBarView(
                                controller: controller,
                                children: [
                                  _buildCompaniesTab(),
                                  _buildConceptsTab(),
                                  _buildRelationsTab(),
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
    return _FinanceCatalogSurface(
      child: Column(
        children: [
          _FinanceFilterSummaryRow(
            labels: [
              for (final name in _companyNameFilters) 'Empresa: $name',
              for (final source in _companySourceFilters) 'Origen: $source',
              if (_companyActiveFilter != null)
                _companyActiveFilter!
                    ? 'Empresas activas'
                    : 'Empresas inactivas',
            ],
            onClearAll:
                _companyNameFilters.isEmpty &&
                    _companySourceFilters.isEmpty &&
                    _companyActiveFilter == null
                ? null
                : () => setState(() {
                    _companyNameFilters = <String>{};
                    _companySourceFilters = <String>{};
                    _companyActiveFilter = null;
                  }),
          ),
          const SizedBox(height: 10),
          _FinanceHeaderRow(
            contentWidth: _FinanzasCatalogPageState._kFinanceCompanyContentW,
            columns: [
              _FinanceHeaderColumn(
                'EMPRESA',
                _kFinanceCompanyNameW,
                onFilter: _pickCompanyNameFilter,
                active: _companyNameFilters.isNotEmpty,
              ),
              _FinanceHeaderColumn(
                'ORIGEN',
                _kFinanceCompanySourceW,
                onFilter: _pickCompanySourceFilter,
                active: _companySourceFilters.isNotEmpty,
              ),
              const _FinanceHeaderColumn('VINCULO', _kFinanceCompanyLinkW),
              _FinanceHeaderColumn(
                'ESTATUS',
                _kFinanceCompanyStatusW,
                onFilter: _pickCompanyActiveFilter,
                active: _companyActiveFilter != null,
              ),
              const _FinanceHeaderColumn('NOTAS', _kFinanceCompanyNotesW),
            ],
          ),
          const SizedBox(height: 10),
          _FinanceInsertRow(
            contentWidth: _FinanzasCatalogPageState._kFinanceCompanyContentW,
            onSubmit: _saveCompany,
            children: [
              _FinanceFieldCell(
                width: _kFinanceCompanyNameW,
                child: _FinanceTextField(
                  controller: _companyNameC,
                  hintText: 'Empresa financiera',
                ),
              ),
              _FinanceFieldCell(
                width: _kFinanceCompanySourceW,
                child: _FinancePickerField<String>(
                  value: _companySource,
                  items: _kFinanceCompanySources,
                  hint: 'Origen',
                  onChanged: (value) =>
                      setState(() => _companySource = value ?? 'DIRECTO'),
                ),
              ),
              _FinanceFieldCell(
                width: _kFinanceCompanyLinkW,
                child: _FinanceTextField(
                  controller: _companyLinkedNameC,
                  hintText: 'Cliente / proveedor / alias',
                ),
              ),
              const _FinanceFieldCell(
                width: _kFinanceCompanyStatusW,
                child: _FinanceStatusPreview(label: 'ACTIVO'),
              ),
              _FinanceFieldCell(
                width: _kFinanceCompanyNotesW,
                child: _FinanceTextField(
                  controller: _companyNotesC,
                  hintText: 'Notas',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Listener(
              onPointerMove: (event) => _handleRowsPointerMove(
                event,
                visibleCompanies
                    .map((item) => 'fc:${item.id}')
                    .toList(growable: false),
              ),
              onPointerUp: (_) => _endDragSelection(),
              onPointerCancel: (_) => _endDragSelection(),
              child: Container(
                key: _companyRowsViewportKey,
                child: ListView.separated(
                  controller: _companyRowsScrollController,
                  itemCount: visibleCompanies.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = visibleCompanies[index];
                    final rowKey = 'fc:${row.id}';
                    final visibleKeys = visibleCompanies
                        .map((item) => 'fc:${item.id}')
                        .toList(growable: false);
                    if (_editingCompanyId == row.id) {
                      return KeyedSubtree(
                        key: _rowItemKey(rowKey),
                        child: _FinanceCompanyInlineEditRow(
                          row: row,
                          onCancel: _cancelCompanyInlineEdit,
                          onSave: (payload) => _saveCompanyInline(row, payload),
                        ),
                      );
                    }
                    return _FinanceTableRow(
                      key: _rowItemKey(rowKey),
                      rowKey: rowKey,
                      selected: _isRowSelected(rowKey),
                      onTap: () => _handleRowSelection(rowKey, visibleKeys),
                      onPrimaryPointerDown: () =>
                          _beginDragSelection(rowKey, visibleKeys),
                      onDragEnter: () => _updateDragSelection(rowKey),
                      onPointerEnd: _endDragSelection,
                      onSecondarySelection: () =>
                          _handleRowSecondarySelection(rowKey, visibleKeys),
                      onDoubleTap: () =>
                          setState(() => _editingCompanyId = row.id),
                      cells: [
                        _FinanceTableCell.text(
                          width: _kFinanceCompanyNameW,
                          text: row.name,
                          bold: true,
                        ),
                        _FinanceTableCell.chip(
                          width: _kFinanceCompanySourceW,
                          label: row.source,
                          tone: _financeSourceTone(row.source),
                        ),
                        _FinanceTableCell.text(
                          width: _kFinanceCompanyLinkW,
                          text: row.linkedName.isEmpty ? '—' : row.linkedName,
                        ),
                        _FinanceTableCell.chip(
                          width: _kFinanceCompanyStatusW,
                          label: row.active ? 'ACTIVO' : 'INACTIVO',
                          tone: row.active
                              ? const Color(0xFF2E8B57)
                              : const Color(0xFFB26A00),
                        ),
                        _FinanceTableCell.text(
                          width: _kFinanceCompanyNotesW,
                          text: row.notes,
                        ),
                      ],
                      menuItems: [
                        _FinanceRowMenuAction(
                          label: 'Editar',
                          icon: Icons.edit_rounded,
                          onTap: () =>
                              setState(() => _editingCompanyId = row.id),
                        ),
                        _FinanceRowMenuAction(
                          label: row.active ? 'Desactivar' : 'Activar',
                          icon: row.active
                              ? Icons.pause_circle_rounded
                              : Icons.check_circle_rounded,
                          onTap: () => _toggleCompanyActive(row),
                        ),
                        _FinanceRowMenuAction(
                          label: 'Eliminar',
                          icon: Icons.delete_outline_rounded,
                          onTap: () => _deleteCompany(row),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConceptsTab() {
    final visibleConcepts = _visibleConcepts;
    return _FinanceCatalogSurface(
      child: Column(
        children: [
          _FinanceFilterSummaryRow(
            labels: [
              for (final name in _conceptNameFilters) 'Concepto: $name',
              for (final family in _conceptFamilyFilters) 'Familia: $family',
              for (final direction in _conceptDirectionFilters)
                'Direccion: $direction',
              if (_conceptActiveFilter != null)
                _conceptActiveFilter!
                    ? 'Conceptos activos'
                    : 'Conceptos inactivos',
            ],
            onClearAll:
                _conceptNameFilters.isEmpty &&
                    _conceptFamilyFilters.isEmpty &&
                    _conceptDirectionFilters.isEmpty &&
                    _conceptActiveFilter == null
                ? null
                : () => setState(() {
                    _conceptNameFilters = <String>{};
                    _conceptFamilyFilters = <String>{};
                    _conceptDirectionFilters = <String>{};
                    _conceptActiveFilter = null;
                  }),
          ),
          const SizedBox(height: 10),
          _FinanceHeaderRow(
            contentWidth: _FinanzasCatalogPageState._kFinanceConceptContentW,
            columns: [
              _FinanceHeaderColumn(
                'CONCEPTO',
                _kFinanceConceptNameW,
                onFilter: _pickConceptNameFilter,
                active: _conceptNameFilters.isNotEmpty,
              ),
              _FinanceHeaderColumn(
                'FAMILIA',
                _kFinanceConceptFamilyW,
                onFilter: _pickConceptFamilyFilter,
                active: _conceptFamilyFilters.isNotEmpty,
              ),
              _FinanceHeaderColumn(
                'DIRECCION',
                _kFinanceConceptDirectionW,
                onFilter: _pickConceptDirectionFilter,
                active: _conceptDirectionFilters.isNotEmpty,
              ),
              const _FinanceHeaderColumn('REGLA', _kFinanceConceptRulesW),
              _FinanceHeaderColumn(
                'ESTATUS',
                _kFinanceConceptStatusW,
                onFilter: _pickConceptActiveFilter,
                active: _conceptActiveFilter != null,
              ),
              const _FinanceHeaderColumn('NOTAS', _kFinanceConceptNotesW),
            ],
          ),
          const SizedBox(height: 10),
          _FinanceInsertRow(
            contentWidth: _FinanzasCatalogPageState._kFinanceConceptContentW,
            onSubmit: _saveConcept,
            children: [
              _FinanceFieldCell(
                width: _kFinanceConceptNameW,
                child: _FinanceTextField(
                  controller: _conceptNameC,
                  hintText: 'Concepto financiero',
                ),
              ),
              _FinanceFieldCell(
                width: _kFinanceConceptFamilyW,
                child: _FinancePickerField<String>(
                  value: _conceptFamily,
                  items: _kFinanceConceptFamilies,
                  hint: 'Familia',
                  onChanged: (value) =>
                      setState(() => _conceptFamily = value ?? 'GASTO'),
                ),
              ),
              _FinanceFieldCell(
                width: _kFinanceConceptDirectionW,
                child: _FinancePickerField<String>(
                  value: _conceptDirection,
                  items: _kFinanceDirections,
                  hint: 'Direccion',
                  onChanged: (value) =>
                      setState(() => _conceptDirection = value ?? 'SALIDA'),
                ),
              ),
              _FinanceFieldCell(
                width: _kFinanceConceptRulesW,
                child: _FinanceBoolToggle(
                  value: _conceptRequiresCompany,
                  label: _conceptRequiresCompany
                      ? 'REQUIERE EMPRESA'
                      : 'EMPRESA OPCIONAL',
                  onChanged: (value) =>
                      setState(() => _conceptRequiresCompany = value),
                ),
              ),
              const _FinanceFieldCell(
                width: _kFinanceConceptStatusW,
                child: _FinanceStatusPreview(label: 'ACTIVO'),
              ),
              _FinanceFieldCell(
                width: _kFinanceConceptNotesW,
                child: _FinanceTextField(
                  controller: _conceptNotesC,
                  hintText: 'Notas',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Listener(
              onPointerMove: (event) => _handleRowsPointerMove(
                event,
                visibleConcepts
                    .map((item) => 'fn:${item.id}')
                    .toList(growable: false),
              ),
              onPointerUp: (_) => _endDragSelection(),
              onPointerCancel: (_) => _endDragSelection(),
              child: Container(
                key: _conceptRowsViewportKey,
                child: ListView.separated(
                  controller: _conceptRowsScrollController,
                  itemCount: visibleConcepts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = visibleConcepts[index];
                    final rowKey = 'fn:${row.id}';
                    final visibleKeys = visibleConcepts
                        .map((item) => 'fn:${item.id}')
                        .toList(growable: false);
                    if (_editingConceptId == row.id) {
                      return KeyedSubtree(
                        key: _rowItemKey(rowKey),
                        child: _FinanceConceptInlineEditRow(
                          row: row,
                          onCancel: _cancelConceptInlineEdit,
                          onSave: (payload) => _saveConceptInline(row, payload),
                        ),
                      );
                    }
                    return _FinanceTableRow(
                      key: _rowItemKey(rowKey),
                      rowKey: rowKey,
                      selected: _isRowSelected(rowKey),
                      onTap: () => _handleRowSelection(rowKey, visibleKeys),
                      onPrimaryPointerDown: () =>
                          _beginDragSelection(rowKey, visibleKeys),
                      onDragEnter: () => _updateDragSelection(rowKey),
                      onPointerEnd: _endDragSelection,
                      onSecondarySelection: () =>
                          _handleRowSecondarySelection(rowKey, visibleKeys),
                      onDoubleTap: () =>
                          setState(() => _editingConceptId = row.id),
                      cells: [
                        _FinanceTableCell.text(
                          width: _kFinanceConceptNameW,
                          text: row.name,
                          bold: true,
                        ),
                        _FinanceTableCell.chip(
                          width: _kFinanceConceptFamilyW,
                          label: row.family,
                          tone: _financeFamilyTone(row.family),
                        ),
                        _FinanceTableCell.chip(
                          width: _kFinanceConceptDirectionW,
                          label: row.direction,
                          tone: _financeDirectionTone(row.direction),
                        ),
                        _FinanceTableCell.text(
                          width: _kFinanceConceptRulesW,
                          text: row.requiresCompany
                              ? 'REQUIERE EMPRESA'
                              : 'EMPRESA OPCIONAL',
                        ),
                        _FinanceTableCell.chip(
                          width: _kFinanceConceptStatusW,
                          label: row.active ? 'ACTIVO' : 'INACTIVO',
                          tone: row.active
                              ? const Color(0xFF2E8B57)
                              : const Color(0xFFB26A00),
                        ),
                        _FinanceTableCell.text(
                          width: _kFinanceConceptNotesW,
                          text: row.notes,
                        ),
                      ],
                      menuItems: [
                        _FinanceRowMenuAction(
                          label: 'Editar',
                          icon: Icons.edit_rounded,
                          onTap: () =>
                              setState(() => _editingConceptId = row.id),
                        ),
                        _FinanceRowMenuAction(
                          label: row.active ? 'Desactivar' : 'Activar',
                          icon: row.active
                              ? Icons.pause_circle_rounded
                              : Icons.check_circle_rounded,
                          onTap: () => _toggleConceptActive(row),
                        ),
                        _FinanceRowMenuAction(
                          label: 'Eliminar',
                          icon: Icons.delete_outline_rounded,
                          onTap: () => _deleteConcept(row),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelationsTab() {
    final visibleRelations = _visibleRelations;
    return _FinanceCatalogSurface(
      child: Column(
        children: [
          _FinanceFilterSummaryRow(
            labels: [
              if (_relationCompanyFilterId != null)
                'Empresa: ${_companyNameById(_relationCompanyFilterId!)}',
              if (_relationConceptFilterId != null)
                'Concepto: ${_conceptNameById(_relationConceptFilterId!)}',
              for (final mode in _relationModeFilters) 'Modo: $mode',
              if (_relationActiveFilter != null)
                _relationActiveFilter!
                    ? 'Relaciones activas'
                    : 'Relaciones inactivas',
            ],
            onClearAll:
                _relationCompanyFilterId == null &&
                    _relationConceptFilterId == null &&
                    _relationModeFilters.isEmpty &&
                    _relationActiveFilter == null
                ? null
                : () => setState(() {
                    _relationCompanyFilterId = null;
                    _relationConceptFilterId = null;
                    _relationModeFilters = <String>{};
                    _relationActiveFilter = null;
                  }),
          ),
          const SizedBox(height: 10),
          _FinanceHeaderRow(
            contentWidth: _FinanzasCatalogPageState._kFinanceRelationContentW,
            columns: [
              _FinanceHeaderColumn(
                'EMPRESA',
                _kFinanceRelationCompanyW,
                onFilter: _pickRelationCompanyFilter,
                active: _relationCompanyFilterId != null,
              ),
              _FinanceHeaderColumn(
                'CONCEPTO',
                _kFinanceRelationConceptW,
                onFilter: _pickRelationConceptFilter,
                active: _relationConceptFilterId != null,
              ),
              _FinanceHeaderColumn(
                'MODO',
                _kFinanceRelationModeW,
                onFilter: _pickRelationModeFilter,
                active: _relationModeFilters.isNotEmpty,
              ),
              _FinanceHeaderColumn(
                'ESTATUS',
                _kFinanceRelationStatusW,
                onFilter: _pickRelationActiveFilter,
                active: _relationActiveFilter != null,
              ),
              const _FinanceHeaderColumn('NOTAS', _kFinanceRelationNotesW),
            ],
          ),
          const SizedBox(height: 10),
          _FinanceInsertRow(
            contentWidth: _FinanzasCatalogPageState._kFinanceRelationContentW,
            onSubmit: _saveRelation,
            children: [
              _FinanceFieldCell(
                width: _kFinanceRelationCompanyW,
                child: _FinancePickerField<String>(
                  value: _relationCompanyId,
                  items: _companies
                      .map((row) => row.id)
                      .toList(growable: false),
                  hint: 'Empresa',
                  labelBuilder: _companyNameById,
                  onChanged: (value) =>
                      setState(() => _relationCompanyId = value),
                ),
              ),
              _FinanceFieldCell(
                width: _kFinanceRelationConceptW,
                child: _FinancePickerField<String>(
                  value: _relationConceptId,
                  items: _concepts.map((row) => row.id).toList(growable: false),
                  hint: 'Concepto',
                  labelBuilder: _conceptNameById,
                  onChanged: (value) =>
                      setState(() => _relationConceptId = value),
                ),
              ),
              _FinanceFieldCell(
                width: _kFinanceRelationModeW,
                child: _FinancePickerField<String>(
                  value: _relationMode,
                  items: _kFinanceRelationModes,
                  hint: 'Modo',
                  onChanged: (value) =>
                      setState(() => _relationMode = value ?? 'MANUAL'),
                ),
              ),
              const _FinanceFieldCell(
                width: _kFinanceRelationStatusW,
                child: _FinanceStatusPreview(label: 'ACTIVO'),
              ),
              _FinanceFieldCell(
                width: _kFinanceRelationNotesW,
                child: _FinanceTextField(
                  controller: _relationNotesC,
                  hintText: 'Notas',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Listener(
              onPointerMove: (event) => _handleRowsPointerMove(
                event,
                visibleRelations
                    .map((item) => 'fr:${item.id}')
                    .toList(growable: false),
              ),
              onPointerUp: (_) => _endDragSelection(),
              onPointerCancel: (_) => _endDragSelection(),
              child: Container(
                key: _relationRowsViewportKey,
                child: ListView.separated(
                  controller: _relationRowsScrollController,
                  itemCount: visibleRelations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = visibleRelations[index];
                    final rowKey = 'fr:${row.id}';
                    final visibleKeys = visibleRelations
                        .map((item) => 'fr:${item.id}')
                        .toList(growable: false);
                    if (_editingRelationId == row.id) {
                      return KeyedSubtree(
                        key: _rowItemKey(rowKey),
                        child: _FinanceRelationInlineEditRow(
                          row: row,
                          companies: _companies,
                          concepts: _concepts,
                          onCancel: _cancelRelationInlineEdit,
                          onSave: (payload) =>
                              _saveRelationInline(row, payload),
                        ),
                      );
                    }
                    return _FinanceTableRow(
                      key: _rowItemKey(rowKey),
                      rowKey: rowKey,
                      selected: _isRowSelected(rowKey),
                      onTap: () => _handleRowSelection(rowKey, visibleKeys),
                      onPrimaryPointerDown: () =>
                          _beginDragSelection(rowKey, visibleKeys),
                      onDragEnter: () => _updateDragSelection(rowKey),
                      onPointerEnd: _endDragSelection,
                      onSecondarySelection: () =>
                          _handleRowSecondarySelection(rowKey, visibleKeys),
                      onDoubleTap: () =>
                          setState(() => _editingRelationId = row.id),
                      cells: [
                        _FinanceTableCell.text(
                          width: _kFinanceRelationCompanyW,
                          text: _companyNameById(row.companyId),
                          bold: true,
                        ),
                        _FinanceTableCell.text(
                          width: _kFinanceRelationConceptW,
                          text: _conceptNameById(row.conceptId),
                        ),
                        _FinanceTableCell.chip(
                          width: _kFinanceRelationModeW,
                          label: row.mode,
                          tone: _financeRelationModeTone(row.mode),
                        ),
                        _FinanceTableCell.chip(
                          width: _kFinanceRelationStatusW,
                          label: row.active ? 'ACTIVO' : 'INACTIVO',
                          tone: row.active
                              ? const Color(0xFF2E8B57)
                              : const Color(0xFFB26A00),
                        ),
                        _FinanceTableCell.text(
                          width: _kFinanceRelationNotesW,
                          text: row.notes,
                        ),
                      ],
                      menuItems: [
                        _FinanceRowMenuAction(
                          label: 'Editar',
                          icon: Icons.edit_rounded,
                          onTap: () =>
                              setState(() => _editingRelationId = row.id),
                        ),
                        _FinanceRowMenuAction(
                          label: row.active ? 'Desactivar' : 'Activar',
                          icon: row.active
                              ? Icons.pause_circle_rounded
                              : Icons.check_circle_rounded,
                          onTap: () => _toggleRelationActive(row),
                        ),
                        _FinanceRowMenuAction(
                          label: 'Eliminar',
                          icon: Icons.delete_outline_rounded,
                          onTap: () => _deleteRelation(row),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceCatalogSurface extends StatelessWidget {
  final Widget child;

  const _FinanceCatalogSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: child,
    );
  }
}

class _FinanceFilterSummaryRow extends StatelessWidget {
  final List<String> labels;
  final VoidCallback? onClearAll;

  const _FinanceFilterSummaryRow({required this.labels, this.onClearAll});

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty && onClearAll == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: finanzasAreaTokens.badgeBackground.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: finanzasAreaTokens.border.withValues(alpha: 0.70),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: kFinanzasInk,
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

class _FinanceHeaderColumn {
  final String label;
  final double width;
  final VoidCallback? onFilter;
  final bool active;

  const _FinanceHeaderColumn(
    this.label,
    this.width, {
    this.onFilter,
    this.active = false,
  });
}

class _FinanceHeaderRow extends StatelessWidget {
  final List<_FinanceHeaderColumn> columns;
  final double contentWidth;

  const _FinanceHeaderRow({required this.columns, required this.contentWidth});

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
            return SizedBox(
              width: constraints.maxWidth,
              child: ContractGridScaledRow(
                child: SizedBox(
                  width:
                      contentWidth +
                      _FinanzasCatalogPageState._kFinanceActionsW,
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
                      const SizedBox(
                        width: _FinanzasCatalogPageState._kFinanceActionsW,
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

class _FinanceInsertRow extends StatelessWidget {
  final double contentWidth;
  final List<Widget> children;
  final VoidCallback? onSubmit;
  final Widget? actionChild;
  final bool editing;
  final String? statusLabel;

  const _FinanceInsertRow({
    required this.contentWidth,
    required this.children,
    this.onSubmit,
    this.actionChild,
    this.editing = false,
    this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: editing
            ? finanzasAreaTokens.badgeBackground.withValues(alpha: 0.68)
            : Colors.white.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: editing
              ? finanzasAreaTokens.primaryStrong.withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.28),
          width: editing ? 1.4 : 1,
        ),
        boxShadow: editing
            ? [
                BoxShadow(
                  color: finanzasAreaTokens.glow.withValues(alpha: 0.14),
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
                        color: finanzasAreaTokens.primaryStrong,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusLabel!,
                      style: TextStyle(
                        color: finanzasAreaTokens.primaryStrong,
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
                    child: SizedBox(
                      width:
                          contentWidth +
                          _FinanzasCatalogPageState._kFinanceActionsW,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...children,
                          AnchoredActionSlot(
                            width: _FinanzasCatalogPageState._kFinanceActionsW,
                            trailingWidth:
                                _FinanzasCatalogPageState._kFinanceActionsW,
                            leading: const SizedBox.shrink(),
                            trailing: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child:
                                  actionChild ??
                                  _FinanceAddButton(onTap: onSubmit),
                            ),
                          ),
                        ],
                      ),
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

class _FinanceFieldCell extends StatelessWidget {
  final double width;
  final Widget child;

  const _FinanceFieldCell({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(padding: const EdgeInsets.only(right: 10), child: child),
    );
  }
}

class _FinanceAddButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _FinanceAddButton({required this.onTap});

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
          color: const Color(
            0xFF19C37D,
          ).withValues(alpha: onTap == null ? 0.28 : 0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.52)),
        ),
        child: const Icon(Icons.add, size: 18, color: Colors.white),
      ),
    );
  }
}

class _FinanceTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const _FinanceTextField({required this.controller, required this.hintText});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      decoration: contractGlassFieldDecoration(context, hintText: hintText),
    );
  }
}

class _FinancePickerField<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String hint;
  final ValueChanged<T?> onChanged;
  final String Function(T value)? labelBuilder;

  const _FinancePickerField({
    required this.value,
    required this.items,
    required this.hint,
    required this.onChanged,
    this.labelBuilder,
  });

  Future<void> _openPicker(BuildContext context) async {
    final selected = await _showFinanceSingleSelectDialog<T>(
      context,
      title: hint,
      initialValue: value,
      options: items
          .map(
            (item) => _FinancePickerOption<T>(
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
        ? hint
        : (labelBuilder == null ? value.toString() : labelBuilder!(value as T));
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openPicker(context),
      child: InputDecorator(
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
                  color: value == null ? kFinanzasMutedInk : kFinanzasInk,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _FinanceBoolToggle extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  const _FinanceBoolToggle({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onChanged(!value),
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.72),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: finanzasAreaTokens.border.withValues(alpha: 0.9),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: finanzasAreaTokens.primaryStrong),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
        ),
        child: Row(
          children: [
            Switch(value: value, onChanged: onChanged),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceStatusPreview extends StatelessWidget {
  final String label;

  const _FinanceStatusPreview({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: _FinanceRowChip(label: label, tone: const Color(0xFF2E8B57)),
    );
  }
}

class _FinanceTableCell {
  final double width;
  final Widget child;

  const _FinanceTableCell._({required this.width, required this.child});

  factory _FinanceTableCell.text({
    required double width,
    required String text,
    bool bold = false,
  }) {
    return _FinanceTableCell._(
      width: width,
      child: Text(
        text.isEmpty ? '—' : text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
          color: kFinanzasInk,
        ),
      ),
    );
  }

  factory _FinanceTableCell.chip({
    required double width,
    required String label,
    required Color tone,
  }) {
    return _FinanceTableCell._(
      width: width,
      child: Align(
        alignment: Alignment.centerLeft,
        child: _FinanceRowChip(label: label, tone: tone),
      ),
    );
  }
}

class _FinanceTableRow extends StatefulWidget {
  final String rowKey;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onPrimaryPointerDown;
  final VoidCallback? onDragEnter;
  final VoidCallback? onPointerEnd;
  final VoidCallback? onSecondarySelection;
  final List<_FinanceTableCell> cells;
  final List<_FinanceRowMenuAction> menuItems;
  final VoidCallback? onDoubleTap;

  const _FinanceTableRow({
    super.key,
    required this.rowKey,
    required this.selected,
    required this.onTap,
    this.onPrimaryPointerDown,
    this.onDragEnter,
    this.onPointerEnd,
    this.onSecondarySelection,
    required this.cells,
    required this.menuItems,
    this.onDoubleTap,
  });

  @override
  State<_FinanceTableRow> createState() => _FinanceTableRowState();
}

class _FinanceTableRowState extends State<_FinanceTableRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final selected = widget.selected;
    final rowContentWidth = widget.cells.fold<double>(
      _FinanzasCatalogPageState._kFinanceActionsW,
      (sum, cell) => sum + cell.width,
    );
    final background = selected
        ? tokens.badgeBackground.withValues(alpha: 0.94)
        : _hovering
        ? Colors.white.withValues(alpha: 0.84)
        : Colors.white.withValues(alpha: 0.66);
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
                      onSecondaryTapDown: (_) =>
                          widget.onSecondarySelection?.call(),
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
                                  for (final cell in widget.cells)
                                    SizedBox(
                                      width: cell.width,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 10,
                                        ),
                                        child: cell.child,
                                      ),
                                    ),
                                  AnchoredActionSlot(
                                    width: _FinanzasCatalogPageState
                                        ._kFinanceActionsW,
                                    trailingWidth: 36,
                                    leading: const SizedBox.shrink(),
                                    trailing:
                                        PopupMenuButton<_FinanceRowMenuAction>(
                                          tooltip: 'Acciones',
                                          padding: EdgeInsets.zero,
                                          color: finanzasAreaTokens.surfaceTint
                                              .withValues(alpha: 0.98),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
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
                                              PopupMenuItem<
                                                _FinanceRowMenuAction
                                              >(
                                                value: item,
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      item.icon,
                                                      color: finanzasAreaTokens
                                                          .primaryStrong,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      item.label,
                                                      style: const TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: kFinanzasInk,
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
                                                  ? tokens.primarySoft
                                                        .withValues(alpha: 0.42)
                                                  : Colors.white.withValues(
                                                      alpha: 0.88,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: selected
                                                    ? tokens.primaryStrong
                                                          .withValues(
                                                            alpha: 0.36,
                                                          )
                                                    : tokens.border.withValues(
                                                        alpha: 0.82,
                                                      ),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                  color: Colors.black
                                                      .withValues(alpha: 0.06),
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

class _FinanceCompanyInlineEditRow extends StatefulWidget {
  final _FinanceCompany row;
  final VoidCallback onCancel;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _FinanceCompanyInlineEditRow({
    required this.row,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_FinanceCompanyInlineEditRow> createState() =>
      _FinanceCompanyInlineEditRowState();
}

class _FinanceCompanyInlineEditRowState
    extends State<_FinanceCompanyInlineEditRow> {
  late final TextEditingController _nameC;
  late final TextEditingController _linkedNameC;
  late final TextEditingController _notesC;
  late String _source;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.row.name);
    _linkedNameC = TextEditingController(text: widget.row.linkedName);
    _notesC = TextEditingController(text: widget.row.notes);
    _source = widget.row.source;
    _active = widget.row.active;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _linkedNameC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSave({
      'name': _nameC.text,
      'source': _source,
      'linkedName': _linkedNameC.text,
      'active': _active,
      'notes': _notesC.text,
    });
  }

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
        child: _FinanceInsertRow(
          contentWidth: _FinanzasCatalogPageState._kFinanceCompanyContentW,
          editing: true,
          statusLabel: 'EDITANDO EMPRESA',
          actionChild: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FinanceActionButton(
                onTap: widget.onCancel,
                icon: Icons.close_rounded,
                color: const Color(0xFF8F6D5A),
              ),
              const SizedBox(width: 8),
              _FinanceActionButton(
                onTap: _submit,
                icon: Icons.check_rounded,
                color: const Color(0xFF19C37D),
              ),
            ],
          ),
          children: [
            _FinanceFieldCell(
              width: _FinanzasCatalogPageState._kFinanceCompanyNameW,
              child: _FinanceTextField(
                controller: _nameC,
                hintText: 'Empresa financiera',
              ),
            ),
            _FinanceFieldCell(
              width: _FinanzasCatalogPageState._kFinanceCompanySourceW,
              child: _FinancePickerField<String>(
                value: _source,
                items: _FinanzasCatalogPageState._kFinanceCompanySources,
                hint: 'Origen',
                onChanged: (value) =>
                    setState(() => _source = value ?? widget.row.source),
              ),
            ),
            _FinanceFieldCell(
              width: _FinanzasCatalogPageState._kFinanceCompanyLinkW,
              child: _FinanceTextField(
                controller: _linkedNameC,
                hintText: 'Cliente / proveedor / alias',
              ),
            ),
            _FinanceFieldCell(
              width: _FinanzasCatalogPageState._kFinanceCompanyStatusW,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Switch(
                  value: _active,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) => setState(() => _active = value),
                ),
              ),
            ),
            _FinanceFieldCell(
              width: _FinanzasCatalogPageState._kFinanceCompanyNotesW,
              child: _FinanceTextField(controller: _notesC, hintText: 'Notas'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceConceptInlineEditRow extends StatefulWidget {
  final _FinanceConcept row;
  final VoidCallback onCancel;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _FinanceConceptInlineEditRow({
    required this.row,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_FinanceConceptInlineEditRow> createState() =>
      _FinanceConceptInlineEditRowState();
}

class _FinanceConceptInlineEditRowState
    extends State<_FinanceConceptInlineEditRow> {
  late final TextEditingController _nameC;
  late final TextEditingController _notesC;
  late String _family;
  late String _direction;
  late bool _requiresCompany;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.row.name);
    _notesC = TextEditingController(text: widget.row.notes);
    _family = widget.row.family;
    _direction = widget.row.direction;
    _requiresCompany = widget.row.requiresCompany;
    _active = widget.row.active;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSave({
      'name': _nameC.text,
      'family': _family,
      'direction': _direction,
      'requiresCompany': _requiresCompany,
      'active': _active,
      'notes': _notesC.text,
    });
  }

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
        child: _FinanceInsertRow(
          contentWidth: _FinanzasCatalogPageState._kFinanceConceptContentW,
          editing: true,
          statusLabel: 'EDITANDO CONCEPTO',
          actionChild: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FinanceActionButton(
                onTap: widget.onCancel,
                icon: Icons.close_rounded,
                color: const Color(0xFF8F6D5A),
              ),
              const SizedBox(width: 8),
              _FinanceActionButton(
                onTap: _submit,
                icon: Icons.check_rounded,
                color: const Color(0xFF19C37D),
              ),
            ],
          ),
          children: [
            _FinanceFieldCell(
              width: _FinanzasCatalogPageState._kFinanceConceptNameW,
              child: _FinanceTextField(
                controller: _nameC,
                hintText: 'Concepto financiero',
              ),
            ),
            _FinanceFieldCell(
              width: _FinanzasCatalogPageState._kFinanceConceptFamilyW,
              child: _FinancePickerField<String>(
                value: _family,
                items: _FinanzasCatalogPageState._kFinanceConceptFamilies,
                hint: 'Familia',
                onChanged: (value) =>
                    setState(() => _family = value ?? widget.row.family),
              ),
            ),
            _FinanceFieldCell(
              width: _FinanzasCatalogPageState._kFinanceConceptDirectionW,
              child: _FinancePickerField<String>(
                value: _direction,
                items: _FinanzasCatalogPageState._kFinanceDirections,
                hint: 'Direccion',
                onChanged: (value) =>
                    setState(() => _direction = value ?? widget.row.direction),
              ),
            ),
            _FinanceFieldCell(
              width: _FinanzasCatalogPageState._kFinanceConceptRulesW,
              child: _FinanceBoolToggle(
                value: _requiresCompany,
                label: _requiresCompany
                    ? 'REQUIERE EMPRESA'
                    : 'EMPRESA OPCIONAL',
                onChanged: (value) => setState(() => _requiresCompany = value),
              ),
            ),
            _FinanceFieldCell(
              width: _FinanzasCatalogPageState._kFinanceConceptStatusW,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Switch(
                  value: _active,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) => setState(() => _active = value),
                ),
              ),
            ),
            _FinanceFieldCell(
              width: _FinanzasCatalogPageState._kFinanceConceptNotesW,
              child: _FinanceTextField(controller: _notesC, hintText: 'Notas'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceRelationInlineEditRow extends StatefulWidget {
  final _FinanceRelation row;
  final List<_FinanceCompany> companies;
  final List<_FinanceConcept> concepts;
  final VoidCallback onCancel;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _FinanceRelationInlineEditRow({
    required this.row,
    required this.companies,
    required this.concepts,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_FinanceRelationInlineEditRow> createState() =>
      _FinanceRelationInlineEditRowState();
}

class _FinanceRelationInlineEditRowState
    extends State<_FinanceRelationInlineEditRow> {
  late String _companyId;
  late String _conceptId;
  late String _mode;
  late bool _active;
  late final TextEditingController _notesC;

  @override
  void initState() {
    super.initState();
    _companyId = widget.row.companyId;
    _conceptId = widget.row.conceptId;
    _mode = widget.row.mode;
    _active = widget.row.active;
    _notesC = TextEditingController(text: widget.row.notes);
  }

  @override
  void dispose() {
    _notesC.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSave({
      'companyId': _companyId,
      'conceptId': _conceptId,
      'mode': _mode,
      'active': _active,
      'notes': _notesC.text,
    });
  }

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
        child: _FinanceInsertRow(
          contentWidth: _FinanzasCatalogPageState._kFinanceRelationContentW,
          editing: true,
          statusLabel: 'EDITANDO RELACION',
          actionChild: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FinanceActionButton(
                onTap: widget.onCancel,
                icon: Icons.close_rounded,
                color: const Color(0xFF8F6D5A),
              ),
              const SizedBox(width: 8),
              _FinanceActionButton(
                onTap: _submit,
                icon: Icons.check_rounded,
                color: const Color(0xFF19C37D),
              ),
            ],
          ),
          children: [
            _FinanceFieldCell(
              width: _FinanzasCatalogPageState._kFinanceRelationCompanyW,
              child: _FinancePickerField<String>(
                value: _companyId,
                items: widget.companies
                    .map((row) => row.id)
                    .toList(growable: false),
                hint: 'Empresa',
                labelBuilder: (value) =>
                    widget.companies.firstWhere((row) => row.id == value).name,
                onChanged: (value) =>
                    setState(() => _companyId = value ?? widget.row.companyId),
              ),
            ),
            _FinanceFieldCell(
              width: _FinanzasCatalogPageState._kFinanceRelationConceptW,
              child: _FinancePickerField<String>(
                value: _conceptId,
                items: widget.concepts
                    .map((row) => row.id)
                    .toList(growable: false),
                hint: 'Concepto',
                labelBuilder: (value) =>
                    widget.concepts.firstWhere((row) => row.id == value).name,
                onChanged: (value) =>
                    setState(() => _conceptId = value ?? widget.row.conceptId),
              ),
            ),
            _FinanceFieldCell(
              width: _FinanzasCatalogPageState._kFinanceRelationModeW,
              child: _FinancePickerField<String>(
                value: _mode,
                items: _FinanzasCatalogPageState._kFinanceRelationModes,
                hint: 'Modo',
                onChanged: (value) =>
                    setState(() => _mode = value ?? widget.row.mode),
              ),
            ),
            _FinanceFieldCell(
              width: _FinanzasCatalogPageState._kFinanceRelationStatusW,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Switch(
                  value: _active,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) => setState(() => _active = value),
                ),
              ),
            ),
            _FinanceFieldCell(
              width: _FinanzasCatalogPageState._kFinanceRelationNotesW,
              child: _FinanceTextField(controller: _notesC, hintText: 'Notas'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceActionButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final Color color;

  const _FinanceActionButton({
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

class _FinanceRowChip extends StatelessWidget {
  final String label;
  final Color tone;

  const _FinanceRowChip({required this.label, required this.tone});

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

class _FinancePickerOption<T> {
  final T value;
  final String label;

  const _FinancePickerOption({required this.value, required this.label});
}

Future<T?> _showFinanceSingleSelectDialog<T>(
  BuildContext context, {
  required String title,
  required List<_FinancePickerOption<T>> options,
  T? initialValue,
  bool allowClear = false,
}) {
  final normalizedOptions = options.toList(growable: false)
    ..sort((a, b) => compareMayoreoAlpha(a.label, b.label));
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      final searchC = TextEditingController();
      final searchFocus = FocusNode();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (searchFocus.canRequestFocus) {
          searchFocus.requestFocus();
        }
      });
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
          final filtered = normalizedOptions
              .where(
                (option) =>
                    option.label.toLowerCase().contains(query.toLowerCase()),
              )
              .toList(growable: false);
          syncNodes(filtered.length);
          return AreaThemeScope(
            tokens: finanzasAreaTokens,
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
                            color: finanzasAreaTokens.primaryStrong,
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
                                  color: finanzasAreaTokens.primaryStrong,
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
                                      child: _FinancePickerOptionTile(
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

Future<Set<T>?> _showFinanceMultiSelectDialog<T>(
  BuildContext context, {
  required String title,
  required List<_FinancePickerOption<T>> options,
  Set<T> initialValues = const {},
}) {
  final normalizedOptions = options.toList(growable: false)
    ..sort((a, b) => compareMayoreoAlpha(a.label, b.label));
  return showDialog<Set<T>>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      final searchC = TextEditingController();
      final searchFocus = FocusNode();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (searchFocus.canRequestFocus) {
          searchFocus.requestFocus();
        }
      });
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
          final filtered = normalizedOptions
              .where(
                (option) =>
                    option.label.toLowerCase().contains(query.toLowerCase()),
              )
              .toList(growable: false);
          syncNodes(filtered.length);
          return AreaThemeScope(
            tokens: finanzasAreaTokens,
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
                            color: finanzasAreaTokens.primaryStrong,
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
                                      child: _FinancePickerOptionTile(
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

class _FinancePickerOptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  const _FinancePickerOptionTile({
    required this.label,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? finanzasAreaTokens.badgeBackground.withValues(alpha: 0.90)
        : highlighted
        ? finanzasAreaTokens.surfaceTint.withValues(alpha: 0.66)
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
                      color: kFinanzasInk,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: finanzasAreaTokens.primaryStrong,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinanceRowMenuAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _FinanceRowMenuAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class _FinanceCompany {
  final String id;
  final String name;
  final String source;
  final String linkedName;
  final bool active;
  final String notes;

  const _FinanceCompany({
    required this.id,
    required this.name,
    required this.source,
    required this.linkedName,
    required this.active,
    required this.notes,
  });

  const _FinanceCompany.empty()
    : id = '',
      name = '',
      source = '',
      linkedName = '',
      active = false,
      notes = '';

  _FinanceCompany copyWith({
    String? id,
    String? name,
    String? source,
    String? linkedName,
    bool? active,
    String? notes,
  }) {
    return _FinanceCompany(
      id: id ?? this.id,
      name: name ?? this.name,
      source: source ?? this.source,
      linkedName: linkedName ?? this.linkedName,
      active: active ?? this.active,
      notes: notes ?? this.notes,
    );
  }
}

class _FinanceConcept {
  final String id;
  final String name;
  final String family;
  final String direction;
  final bool requiresCompany;
  final bool active;
  final String notes;

  const _FinanceConcept({
    required this.id,
    required this.name,
    required this.family,
    required this.direction,
    required this.requiresCompany,
    required this.active,
    required this.notes,
  });

  const _FinanceConcept.empty()
    : id = '',
      name = '',
      family = '',
      direction = '',
      requiresCompany = false,
      active = false,
      notes = '';

  _FinanceConcept copyWith({
    String? id,
    String? name,
    String? family,
    String? direction,
    bool? requiresCompany,
    bool? active,
    String? notes,
  }) {
    return _FinanceConcept(
      id: id ?? this.id,
      name: name ?? this.name,
      family: family ?? this.family,
      direction: direction ?? this.direction,
      requiresCompany: requiresCompany ?? this.requiresCompany,
      active: active ?? this.active,
      notes: notes ?? this.notes,
    );
  }
}

class _FinanceRelation {
  final String id;
  final String companyId;
  final String conceptId;
  final String mode;
  final bool active;
  final String notes;

  const _FinanceRelation({
    required this.id,
    required this.companyId,
    required this.conceptId,
    required this.mode,
    required this.active,
    required this.notes,
  });

  _FinanceRelation copyWith({
    String? id,
    String? companyId,
    String? conceptId,
    String? mode,
    bool? active,
    String? notes,
  }) {
    return _FinanceRelation(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      conceptId: conceptId ?? this.conceptId,
      mode: mode ?? this.mode,
      active: active ?? this.active,
      notes: notes ?? this.notes,
    );
  }
}

String _financeId(String prefix) {
  return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
}

String _normalizeFinanceText(String raw) {
  return raw.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

Color _financeSourceTone(String source) {
  switch (source) {
    case 'VENTAS':
      return const Color(0xFF2563EB);
    case 'COMPRAS':
      return const Color(0xFF8F201A);
    default:
      return const Color(0xFF7A1914);
  }
}

Color _financeFamilyTone(String family) {
  switch (family) {
    case 'COBRO':
      return const Color(0xFF2563EB);
    case 'PAGO':
      return const Color(0xFF8F201A);
    case 'GASTO':
      return const Color(0xFFB26A00);
    case 'PRESTAMO':
      return const Color(0xFF6D28D9);
    case 'AJUSTE':
      return const Color(0xFF0F766E);
    default:
      return const Color(0xFF7A1914);
  }
}

Color _financeDirectionTone(String direction) {
  switch (direction) {
    case 'ENTRADA':
      return const Color(0xFF2563EB);
    case 'SALIDA':
      return const Color(0xFF8F201A);
    default:
      return const Color(0xFF6D28D9);
  }
}

Color _financeRelationModeTone(String mode) {
  switch (mode) {
    case 'AUTOMATICA':
      return const Color(0xFF0F766E);
    case 'MIXTA':
      return const Color(0xFF6D28D9);
    default:
      return const Color(0xFFB26A00);
  }
}

class _FinanzasCatalogBackground extends StatelessWidget {
  const _FinanzasCatalogBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFFF7F6),
                const Color(0xFFF7D7D2),
                const Color(0xFFE9A39B),
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
                const Color(0xFFFFFEFE).withValues(alpha: 0.94),
                const Color(0xFFF5D8D4),
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
                const Color(0xFFB12720).withValues(alpha: 0.74),
                const Color(0xFFF6D8D3).withValues(alpha: 0.28),
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
                const Color(0xFF8F201A).withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.94),
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
                    const Color(0xFFD1473E).withValues(alpha: 0.82),
                    const Color(0xFF7A1914).withValues(alpha: 0.78),
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

class _FinanzasCatalogHeaderBrand extends StatelessWidget {
  const _FinanzasCatalogHeaderBrand();

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
            color: const Color(0xFFFBF3F2),
          ),
        ),
      ],
    );
  }
}

class _FinanzasCatalogSidePanel extends StatelessWidget {
  final bool canReturnToDirection;
  final ValueChanged<String> onNavigate;

  const _FinanzasCatalogSidePanel({
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
                'Finanzas',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              if (canReturnToDirection) ...[
                _FinanzasCatalogNavItem(
                  icon: Icons.arrow_back_rounded,
                  title: 'Volver a Dirección',
                  onTap: () async => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 10),
              ],
              const _FinanzasCatalogSectionHeader(label: 'AREA'),
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
                    _FinanzasCatalogNavItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Dashboard Finanzas',
                      subtitle: 'Vista general del área',
                      onTap: () async => onNavigate('Dashboard Finanzas'),
                    ),
                    const SizedBox(height: 8),
                    _FinanzasCatalogNavItem(
                      icon: Icons.price_check_rounded,
                      title: 'Catálogo Finanzas',
                      subtitle: 'Empresas, conceptos y relaciones',
                      accented: true,
                      onTap: () async {},
                    ),
                    const SizedBox(height: 8),
                    _FinanzasCatalogNavItem(
                      icon: Icons.account_balance_rounded,
                      title: 'Directorio Empresas',
                      subtitle: 'Crédito, contacto y operación',
                      onTap: () async => onNavigate('Directorio Empresas'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _FinanzasCatalogSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              if (canReturnToDirection) ...[
                _FinanzasCatalogNavItem(
                  icon: Icons.assessment_outlined,
                  title: 'Dashboard Dirección',
                  subtitle: 'Vista ejecutiva multiarea',
                  onTap: () async => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 8),
              ],
              _FinanzasCatalogNavItem(
                icon: Icons.shopping_cart_checkout_rounded,
                title: 'Dashboard Compras',
                subtitle: 'Tickets y operación de compra',
                onTap: () async => onNavigate('Dashboard Compras'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanzasCatalogSectionHeader extends StatelessWidget {
  final String label;

  const _FinanzasCatalogSectionHeader({required this.label});

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

class _FinanzasCatalogNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool accented;
  final Future<void> Function() onTap;

  const _FinanzasCatalogNavItem({
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
            gradient: accented ? kFinanzasPanelGradient : null,
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

class _FinanzasHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _FinanzasHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_FinanzasHeaderButton> createState() => _FinanzasHeaderButtonState();
}

class _FinanzasHeaderButtonState extends State<_FinanzasHeaderButton> {
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
                  BoxShadow(
                    blurRadius: highlighted ? 20 : 10,
                    color: tokens.glow.withValues(
                      alpha: highlighted ? 0.12 : 0.05,
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
