import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../compras/compras_catalog_page.dart';
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
import 'finanzas_data_store.dart';
import 'finanzas_dashboard_page.dart';
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

  Future<void> _openComprasCatalog() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const ComprasCatalogPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
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
      case 'Catálogo Compras':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openComprasCatalog());
        return;
      case 'Catálogo Finanzas':
        if (_menuOpen) setState(() => _menuOpen = false);
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
      _concepts = <_FinanceConcept>[
        _FinanceConcept(
          id: _financeId('fn'),
          name: name,
          family: _conceptFamily,
          direction: _conceptDirection,
          requiresCompany: _conceptRequiresCompany,
          active: true,
          notes: _conceptNotesC.text.trim(),
        ),
        ..._concepts,
      ];
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
      _relations = <_FinanceRelation>[
        _FinanceRelation(
          id: _financeId('fr'),
          companyId: _relationCompanyId!,
          conceptId: _relationConceptId!,
          mode: _relationMode,
          active: true,
          notes: _relationNotesC.text.trim(),
        ),
        ..._relations,
      ];
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
    });
    await _persistCatalogSnapshot();
  }

  Future<void> _deleteRelation(_FinanceRelation row) async {
    setState(() {
      _relations = _relations
          .where((item) => item.id != row.id)
          .toList(growable: false);
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
          trailingBuilder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FinanzasHeaderButton(
                label: 'Compras',
                icon: Icons.shopping_cart_checkout_rounded,
                onTap: _openComprasCatalog,
              ),
              const SizedBox(width: 10),
              _FinanzasHeaderButton(
                label: 'Dashboard',
                icon: Icons.space_dashboard_rounded,
                onTap: _openFinanzasDashboard,
              ),
              const SizedBox(width: 10),
              _FinanzasHeaderButton(
                label: 'Cerrar sesión',
                icon: Icons.logout_rounded,
                onTap: _logout,
              ),
            ],
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
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(56, 0, 6, 0),
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
                          child: _FinanzasCatalogTopBar(
                            activeTabIndex: _activeTabIndex,
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
    );
  }

  Widget _buildCompaniesTab() {
    return _FinanceCatalogSurface(
      child: Column(
        children: [
          const _FinanceFilterSummaryRow(labels: <String>[]),
          const SizedBox(height: 10),
          const _FinanceHeaderRow(
            contentWidth: _FinanzasCatalogPageState._kFinanceCompanyContentW,
            columns: [
              _FinanceHeaderColumn('EMPRESA', _kFinanceCompanyNameW),
              _FinanceHeaderColumn('ORIGEN', _kFinanceCompanySourceW),
              _FinanceHeaderColumn('VINCULO', _kFinanceCompanyLinkW),
              _FinanceHeaderColumn('ESTATUS', _kFinanceCompanyStatusW),
              _FinanceHeaderColumn('NOTAS', _kFinanceCompanyNotesW),
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
            child: ListView.separated(
              itemCount: _companies.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = _companies[index];
                return _FinanceTableRow(
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
        ],
      ),
    );
  }

  Widget _buildConceptsTab() {
    return _FinanceCatalogSurface(
      child: Column(
        children: [
          const _FinanceFilterSummaryRow(labels: <String>[]),
          const SizedBox(height: 10),
          const _FinanceHeaderRow(
            contentWidth: _FinanzasCatalogPageState._kFinanceConceptContentW,
            columns: [
              _FinanceHeaderColumn('CONCEPTO', _kFinanceConceptNameW),
              _FinanceHeaderColumn('FAMILIA', _kFinanceConceptFamilyW),
              _FinanceHeaderColumn('DIRECCION', _kFinanceConceptDirectionW),
              _FinanceHeaderColumn('REGLA', _kFinanceConceptRulesW),
              _FinanceHeaderColumn('ESTATUS', _kFinanceConceptStatusW),
              _FinanceHeaderColumn('NOTAS', _kFinanceConceptNotesW),
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
            child: ListView.separated(
              itemCount: _concepts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = _concepts[index];
                return _FinanceTableRow(
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
        ],
      ),
    );
  }

  Widget _buildRelationsTab() {
    return _FinanceCatalogSurface(
      child: Column(
        children: [
          const _FinanceFilterSummaryRow(labels: <String>[]),
          const SizedBox(height: 10),
          const _FinanceHeaderRow(
            contentWidth: _FinanzasCatalogPageState._kFinanceRelationContentW,
            columns: [
              _FinanceHeaderColumn('EMPRESA', _kFinanceRelationCompanyW),
              _FinanceHeaderColumn('CONCEPTO', _kFinanceRelationConceptW),
              _FinanceHeaderColumn('MODO', _kFinanceRelationModeW),
              _FinanceHeaderColumn('ESTATUS', _kFinanceRelationStatusW),
              _FinanceHeaderColumn('NOTAS', _kFinanceRelationNotesW),
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
            child: ListView.separated(
              itemCount: _relations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = _relations[index];
                return _FinanceTableRow(
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
        ],
      ),
    );
  }
}

class _FinanzasCatalogTopBar extends StatelessWidget {
  final int activeTabIndex;

  const _FinanzasCatalogTopBar({required this.activeTabIndex});

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      'Catálogo base de empresas financieras',
      'Catálogo base de conceptos financieros',
      'Puente empresa + concepto',
    ];
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: kFinanzasAccentGradient,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.56)),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: finanzasAreaTokens.primaryStrong,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Catálogo Finanzas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: kFinanzasInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  labels[activeTabIndex],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kFinanzasMutedInk,
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

  const _FinanceFilterSummaryRow({required this.labels});

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
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
      ],
    );
  }
}

class _FinanceHeaderColumn {
  final String label;
  final double width;

  const _FinanceHeaderColumn(this.label, this.width);
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
  final VoidCallback onSubmit;

  const _FinanceInsertRow({
    required this.contentWidth,
    required this.children,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
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
                          child: _FinanceAddButton(onTap: onSubmit),
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
  final VoidCallback onTap;

  const _FinanceAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF19C37D).withValues(alpha: 0.92),
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
  final List<_FinanceTableCell> cells;
  final List<_FinanceRowMenuAction> menuItems;

  const _FinanceTableRow({required this.cells, required this.menuItems});

  @override
  State<_FinanceTableRow> createState() => _FinanceTableRowState();
}

class _FinanceTableRowState extends State<_FinanceTableRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final rowContentWidth = widget.cells.fold<double>(
      _FinanzasCatalogPageState._kFinanceActionsW,
      (sum, cell) => sum + cell.width,
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Card(
        elevation: 0,
        color: _hovering
            ? Colors.white.withValues(alpha: 0.84)
            : Colors.white.withValues(alpha: 0.66),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: tokens.border.withValues(alpha: 0.72)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: constraints.maxWidth,
                child: ContractGridScaledRow(
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
                                padding: const EdgeInsets.only(right: 10),
                                child: cell.child,
                              ),
                            ),
                          AnchoredActionSlot(
                            width: _FinanzasCatalogPageState._kFinanceActionsW,
                            trailingWidth: 36,
                            leading: const SizedBox.shrink(),
                            trailing: PopupMenuButton<_FinanceRowMenuAction>(
                              tooltip: 'Acciones',
                              padding: EdgeInsets.zero,
                              color: finanzasAreaTokens.surfaceTint.withValues(
                                alpha: 0.98,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.70),
                                ),
                              ),
                              onSelected: (item) => item.onTap(),
                              itemBuilder: (context) => [
                                for (final item in widget.menuItems)
                                  PopupMenuItem<_FinanceRowMenuAction>(
                                    value: item,
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.icon,
                                          color:
                                              finanzasAreaTokens.primaryStrong,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          item.label,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
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
                                  color: Colors.white.withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: tokens.border.withValues(
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
              );
            },
          ),
        ),
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8E8E5), Color(0xFFE28A7F), Color(0xFF311A1A)],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: -260,
          top: -130,
          child: _backgroundCircle(760, const [
            Color(0xFFFFF7F4),
            Color(0xFFF5CDC8),
          ]),
        ),
        Positioned(
          right: -180,
          top: -70,
          child: _backgroundCircle(580, const [
            Color(0xFFBC2D25),
            Color(0x33241313),
          ]),
        ),
        Positioned(
          left: 20,
          bottom: -260,
          child: _backgroundCircle(640, const [
            Color(0x66241313),
            Color(0xFFFBE8E6),
          ]),
        ),
      ],
    );
  }

  Widget _backgroundCircle(double diameter, List<Color> colors) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: colors),
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
          'Catálogo Finanzas',
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
                  subtitle: 'Regresar a la vista ejecutiva',
                  onTap: () async => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 10),
              ],
              const _FinanzasCatalogSectionHeader(label: 'MENU'),
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
                      icon: Icons.space_dashboard_rounded,
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
                      icon: Icons.shopping_cart_checkout_rounded,
                      title: 'Dashboard Compras',
                      subtitle: 'Cruce operativo con compras',
                      onTap: () async => onNavigate('Dashboard Compras'),
                    ),
                    const SizedBox(height: 8),
                    _FinanzasCatalogNavItem(
                      icon: Icons.storefront_rounded,
                      title: 'Catálogo Compras',
                      subtitle: 'Proveedores, materiales y precios',
                      onTap: () async => onNavigate('Catálogo Compras'),
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
                icon: Icons.account_balance_wallet_outlined,
                title: 'Dashboard Finanzas',
                subtitle: 'Vista general del área',
                onTap: () async => onNavigate('Dashboard Finanzas'),
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

class _FinanzasCatalogNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool accented;
  final Future<void> Function()? onTap;

  const _FinanzasCatalogNavItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accented = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: accented
                  ? kFinanzasHeroGradient
                  : kFinanzasPanelGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accented
                    ? Colors.white.withValues(alpha: 0.72)
                    : Colors.white.withValues(alpha: 0.58),
              ),
              boxShadow: accented
                  ? [
                      BoxShadow(
                        color: tokens.glow.withValues(alpha: 0.20),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: accented ? Colors.white : tokens.primaryStrong,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: accented ? Colors.white : tokens.primaryStrong,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accented
                              ? Colors.white.withValues(alpha: 0.92)
                              : tokens.badgeText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!accented) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: tokens.badgeText,
                    size: 22,
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
              width: 176,
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                children: [
                  Icon(widget.icon, size: 20, color: tokens.primaryStrong),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: tokens.primaryStrong,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
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
