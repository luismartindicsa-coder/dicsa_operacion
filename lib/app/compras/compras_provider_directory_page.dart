// ignore_for_file: unused_element, unused_element_parameter

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../finanzas/finanzas_dashboard_page.dart';
import '../services/inventory_movements_grid.dart';
import '../shared/app_shell.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import 'compras_area_chrome.dart';
import 'compras_catalog_page.dart';
import 'compras_dashboard_page.dart';
import 'compras_price_adjustments_page.dart';
import 'compras_provider_directory_store.dart';
import 'compras_tickets_page.dart';
import 'compras_theme.dart';

const double _kDirActionsW = 96;
const double _kDirProviderW = 280;
const double _kDirCatalogContactW = 180;
const double _kDirOperationalContactW = 180;
const double _kDirPhoneW = 160;
const double _kDirLocationW = 220;
const double _kDirContainersW = 120;
const double _kDirContainerCountW = 110;
const double _kDirCreditDaysW = 120;
const double _kDirPaymentStageW = 150;
const double _kDirNotesW = 280;
const double _kDirContentW =
    _kDirProviderW +
    _kDirCatalogContactW +
    _kDirOperationalContactW +
    _kDirPhoneW +
    _kDirLocationW +
    _kDirContainersW +
    _kDirContainerCountW +
    _kDirCreditDaysW +
    _kDirPaymentStageW +
    _kDirNotesW;

const List<String> _kPaymentStageOptions = <String>[
  'AL_CORRIENTE',
  'ATRASADO',
  'CONVENIO',
  'PAGO_SEMANAL',
];

String _paymentStageLabel(String stage) {
  switch (stage) {
    case 'ATRASADO':
      return 'Atrasado';
    case 'CONVENIO':
      return 'Convenio';
    case 'PAGO_SEMANAL':
      return 'Pago semanal';
    default:
      return 'Al corriente';
  }
}

Color _paymentStageTone(String stage) {
  switch (stage) {
    case 'ATRASADO':
      return const Color(0xFFB42318);
    case 'CONVENIO':
      return const Color(0xFFB7C0C8);
    case 'PAGO_SEMANAL':
      return const Color(0xFF8B5E00);
    default:
      return const Color(0xFF0F766E);
  }
}

class ComprasProviderDirectoryPage extends StatefulWidget {
  final bool instantOpen;

  const ComprasProviderDirectoryPage({super.key, this.instantOpen = false});

  @override
  State<ComprasProviderDirectoryPage> createState() =>
      _ComprasProviderDirectoryPageState();
}

class _ComprasProviderDirectoryPageState
    extends State<ComprasProviderDirectoryPage> {
  bool _canReturnToDirection = false;
  bool _canAccessFinanzasArea = false;
  bool _menuOpen = false;
  bool _loading = true;
  bool _exportingCsv = false;
  bool? _hasContainersFilter;
  bool? _hasCreditFilter;
  String? _paymentStageFilter;
  Set<String> _providerFilters = <String>{};
  Set<String> _catalogContactFilters = <String>{};
  Set<String> _operationalContactFilters = <String>{};
  Set<String> _phoneFilters = <String>{};
  Set<String> _locationFilters = <String>{};
  String? _selectedProviderId;
  List<ComprasProviderDirectoryRecord> _rows =
      <ComprasProviderDirectoryRecord>[];

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadDirectory());
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
      _canAccessFinanzasArea = AuthAccess.canAccessFinanzasArea(profile);
    });
  }

  Future<void> _loadDirectory() async {
    setState(() => _loading = true);
    final rows = await ComprasProviderDirectoryStore.loadDirectory();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
      _selectedProviderId = _sanitizeSelectedProviderId(_selectedProviderId);
    });
  }

  Future<void> _logout() async {
    await signOutAndRouteToLogin(context);
  }

  Future<void> _openDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ComprasDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openCatalog() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ComprasCatalogPage(instantOpen: true)),
    );
  }

  Future<void> _openPriceAdjustments() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ComprasPriceAdjustmentsPage(instantOpen: true)),
    );
  }

  Future<void> _openTickets() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ComprasTicketsPage(instantOpen: true)),
    );
  }

  Future<void> _openFinanzas() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const FinanzasDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Dirección':
        unawaited(_openDirectionDashboard());
        return;
      case 'Dashboard Compras':
        unawaited(_openDashboard());
        return;
      case 'Catálogo Compras':
        unawaited(_openCatalog());
        return;
      case 'Ajuste de precios':
        unawaited(_openPriceAdjustments());
        return;
      case 'Tickets Compras':
        unawaited(_openTickets());
        return;
      case 'Dashboard Finanzas':
        unawaited(_openFinanzas());
        return;
      case 'Directorio Proveedores':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
    }
  }

  List<ComprasProviderDirectoryRecord> get _visibleRows {
    return _rows
        .where((row) {
          if (_providerFilters.isNotEmpty &&
              !_providerFilters.contains(row.providerName)) {
            return false;
          }
          if (_catalogContactFilters.isNotEmpty &&
              !_catalogContactFilters.contains(row.catalogContact)) {
            return false;
          }
          if (_operationalContactFilters.isNotEmpty &&
              !_operationalContactFilters.contains(row.operationalContact)) {
            return false;
          }
          if (_phoneFilters.isNotEmpty && !_phoneFilters.contains(row.phone)) {
            return false;
          }
          if (_locationFilters.isNotEmpty &&
              !_locationFilters.contains(row.location)) {
            return false;
          }
          if (_hasContainersFilter != null &&
              row.hasContainers != _hasContainersFilter) {
            return false;
          }
          if (_hasCreditFilter != null &&
              (row.creditDays > 0) != _hasCreditFilter) {
            return false;
          }
          if (_paymentStageFilter != null &&
              row.paymentStage != _paymentStageFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  String? _sanitizeSelectedProviderId(String? id) {
    if (id == null) return null;
    for (final row in _rows) {
      if (row.providerId == id) return id;
    }
    return null;
  }

  Future<void> _editRow(ComprasProviderDirectoryRecord row) async {
    final saved = await showDialog<ComprasProviderDirectoryRecord>(
      context: context,
      builder: (_) => _ProviderDirectoryEditDialog(row: row),
    );

    if (saved == null) return;
    await _saveRow(saved);
  }

  Future<void> _saveRow(ComprasProviderDirectoryRecord row) async {
    final previous = _rows;
    setState(() {
      _rows = [
        for (final current in _rows)
          if (current.providerId == row.providerId) row else current,
      ];
      _selectedProviderId = row.providerId;
    });
    try {
      await ComprasProviderDirectoryStore.saveDirectoryRow(row);
    } catch (_) {
      if (!mounted) return;
      setState(() => _rows = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar el directorio. Se restauró el estado anterior.',
          ),
        ),
      );
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _exportingCsv = true);
    final rows = <String>[
      'proveedor,contacto_catalogo,contacto_operativo,telefono,ubicacion,contenedores,cantidad_contenedores,dias_credito,situacion_pago,notas_pago',
      for (final row in _visibleRows)
        [
          row.providerName,
          row.catalogContact,
          row.operationalContact,
          row.phone,
          row.location,
          row.hasContainers ? 'SI' : 'NO',
          row.containerCount.toString(),
          row.creditDays.toString(),
          row.paymentStage,
          row.paymentNotes,
        ].map(_csvCell).join(','),
    ];
    try {
      await saveCsvFile(
        fileName: 'compras_directorio_proveedores.csv',
        content: rows.join('\n'),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingCsv = false);
      }
    }
  }

  String _csvCell(String value) =>
      '"${value.replaceAll('"', '""').replaceAll('\n', ' ')}"';

  void _clearAllFilters() {
    setState(() {
      _providerFilters = <String>{};
      _catalogContactFilters = <String>{};
      _operationalContactFilters = <String>{};
      _phoneFilters = <String>{};
      _locationFilters = <String>{};
      _hasContainersFilter = null;
      _hasCreditFilter = null;
      _paymentStageFilter = null;
    });
  }

  bool get _hasActiveFilters =>
      _providerFilters.isNotEmpty ||
      _catalogContactFilters.isNotEmpty ||
      _operationalContactFilters.isNotEmpty ||
      _phoneFilters.isNotEmpty ||
      _locationFilters.isNotEmpty ||
      _hasContainersFilter != null ||
      _hasCreditFilter != null ||
      _paymentStageFilter != null;

  List<String> _uniqueTextOptions(
    String Function(ComprasProviderDirectoryRecord row) valueFor,
  ) {
    final values =
        _rows
            .map(valueFor)
            .where((value) => value.trim().isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort((a, b) => a.toUpperCase().compareTo(b.toUpperCase()));
    return values;
  }

  Future<void> _pickProviderFilter() async {
    final selected = await _showDirectoryMultiSelectDialog<String>(
      context,
      title: 'Filtrar proveedor',
      initialValues: _providerFilters,
      options: _uniqueTextOptions((row) => row.providerName)
          .map(
            (value) =>
                _DirectoryFilterOption<String>(value: value, label: value),
          )
          .toList(growable: false),
    );
    if (!mounted || selected == null) return;
    setState(() => _providerFilters = selected);
  }

  Future<void> _pickCatalogContactFilter() async {
    final selected = await _showDirectoryMultiSelectDialog<String>(
      context,
      title: 'Filtrar contacto catálogo',
      initialValues: _catalogContactFilters,
      options: _uniqueTextOptions((row) => row.catalogContact)
          .map(
            (value) =>
                _DirectoryFilterOption<String>(value: value, label: value),
          )
          .toList(growable: false),
    );
    if (!mounted || selected == null) return;
    setState(() => _catalogContactFilters = selected);
  }

  Future<void> _pickOperationalContactFilter() async {
    final selected = await _showDirectoryMultiSelectDialog<String>(
      context,
      title: 'Filtrar contacto operativo',
      initialValues: _operationalContactFilters,
      options: _uniqueTextOptions((row) => row.operationalContact)
          .map(
            (value) =>
                _DirectoryFilterOption<String>(value: value, label: value),
          )
          .toList(growable: false),
    );
    if (!mounted || selected == null) return;
    setState(() => _operationalContactFilters = selected);
  }

  Future<void> _pickPhoneFilter() async {
    final selected = await _showDirectoryMultiSelectDialog<String>(
      context,
      title: 'Filtrar teléfono',
      initialValues: _phoneFilters,
      options: _uniqueTextOptions((row) => row.phone)
          .map(
            (value) =>
                _DirectoryFilterOption<String>(value: value, label: value),
          )
          .toList(growable: false),
    );
    if (!mounted || selected == null) return;
    setState(() => _phoneFilters = selected);
  }

  Future<void> _pickLocationFilter() async {
    final selected = await _showDirectoryMultiSelectDialog<String>(
      context,
      title: 'Filtrar ubicación',
      initialValues: _locationFilters,
      options: _uniqueTextOptions((row) => row.location)
          .map(
            (value) =>
                _DirectoryFilterOption<String>(value: value, label: value),
          )
          .toList(growable: false),
    );
    if (!mounted || selected == null) return;
    setState(() => _locationFilters = selected);
  }

  Future<void> _pickContainersFilter() async {
    final selected = await _showDirectorySingleSelectDialog<bool>(
      context,
      title: 'Filtrar contenedores',
      initialValue: _hasContainersFilter,
      allowClear: true,
      options: const [
        _DirectoryFilterOption<bool>(value: true, label: 'Con contenedores'),
        _DirectoryFilterOption<bool>(value: false, label: 'Sin contenedores'),
      ],
    );
    if (!mounted) return;
    setState(() => _hasContainersFilter = selected);
  }

  Future<void> _pickCreditFilter() async {
    final selected = await _showDirectorySingleSelectDialog<bool>(
      context,
      title: 'Filtrar crédito',
      initialValue: _hasCreditFilter,
      allowClear: true,
      options: const [
        _DirectoryFilterOption<bool>(value: true, label: 'Con crédito'),
        _DirectoryFilterOption<bool>(value: false, label: 'Sin crédito'),
      ],
    );
    if (!mounted) return;
    setState(() => _hasCreditFilter = selected);
  }

  Future<void> _pickPaymentStageFilter() async {
    final selected = await _showDirectorySingleSelectDialog<String>(
      context,
      title: 'Filtrar situación de pago',
      initialValue: _paymentStageFilter,
      allowClear: true,
      options: _kPaymentStageOptions
          .map(
            (value) => _DirectoryFilterOption<String>(
              value: value,
              label: _paymentStageLabel(value),
            ),
          )
          .toList(growable: false),
    );
    if (!mounted) return;
    setState(() => _paymentStageFilter = selected);
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: comprasAreaTokens,
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
          background: const _ComprasDirectoryBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => ComprasAreaHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => const _ComprasDirectoryHeaderBrand(),
          trailingBuilder: (_, _) => ComprasAreaHeaderButton(
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
                  child: ComprasAreaSidePanel(
                    label: 'Compras Mayoreo',
                    canReturnToDirection: _canReturnToDirection,
                    areaItems: [
                      ComprasAreaNavEntry(
                        icon: Icons.confirmation_number_outlined,
                        title: 'Tickets Compras',
                        subtitle: 'Captura y seguimiento operativo',
                        onTap: () async =>
                            _handleNavigationAction('Tickets Compras'),
                      ),
                      ComprasAreaNavEntry(
                        icon: Icons.tune_rounded,
                        title: 'Ajuste de precios',
                        subtitle: 'Vigentes e historial operativo',
                        onTap: () async =>
                            _handleNavigationAction('Ajuste de precios'),
                      ),
                      ComprasAreaNavEntry(
                        icon: Icons.price_check_rounded,
                        title: 'Catálogo Compras',
                        subtitle: 'Proveedores, materiales y precios',
                        onTap: () async =>
                            _handleNavigationAction('Catálogo Compras'),
                      ),
                      const ComprasAreaNavEntry(
                        icon: Icons.badge_rounded,
                        title: 'Directorio Proveedores',
                        subtitle: 'Crédito, contacto y operación',
                        accented: true,
                      ),
                    ],
                    accessItems: [
                      ComprasAreaNavEntry(
                        icon: Icons.shopping_cart_checkout_rounded,
                        title: 'Dashboard Compras',
                        subtitle: 'Tickets y operación de compra',
                        onTap: () async =>
                            _handleNavigationAction('Dashboard Compras'),
                      ),
                      if (_canAccessFinanzasArea)
                        ComprasAreaNavEntry(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Dashboard Finanzas',
                          subtitle: 'Pagos, liquidez y compromisos',
                          onTap: () async =>
                              _handleNavigationAction('Dashboard Finanzas'),
                        ),
                      if (_canReturnToDirection)
                        ComprasAreaNavEntry(
                          icon: Icons.assessment_outlined,
                          title: 'Dashboard Dirección',
                          subtitle: 'Vista ejecutiva multiarea',
                          onTap: () async =>
                              _handleNavigationAction('Dashboard Dirección'),
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
  }

  Widget _buildBody() {
    final visibleRows = _visibleRows;
    final selected = visibleRows.where(
      (row) => row.providerId == _selectedProviderId,
    );
    final selectedRow = selected.isEmpty ? null : selected.first;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(56, 0, 6, 0),
          child: DefaultTabController(
            length: 1,
            child: Builder(
              builder: (context) {
                final controller = DefaultTabController.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
                      child: InventoryGridTopBar(
                        data: InventoryGridTopBarData(
                          metricIcon: Icons.badge_rounded,
                          metricLabel: 'DIRECTORIO',
                          metricValue: '${_rows.length}',
                          metricSubtitle:
                              '${_rows.where((row) => row.creditDays > 0).length} con crédito definido',
                          exportingCsv: _exportingCsv,
                          gridEditMode: false,
                          canToggleGridEdit: false,
                          canDeleteSelection: false,
                          deletingSelection: false,
                          selectedCount: selectedRow == null ? 0 : 1,
                          activeCellLabel: selectedRow?.providerName,
                          onExportCsv: _exportCsv,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppFolderTabs(
                      controller: controller,
                      maxWidth: 320,
                      showBottomRail: false,
                      items: const [
                        AppFolderTabItem(
                          label: 'Proveedores',
                          icon: Icons.badge_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _DirectorySurface(
                      child: Column(
                        children: [
                          Expanded(
                            child: _loading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : visibleRows.isEmpty
                                ? _DirectoryEmptyState(
                                    hasActiveFilters: _hasActiveFilters,
                                    onReload: _loadDirectory,
                                    onClearFilters: _hasActiveFilters
                                        ? _clearAllFilters
                                        : null,
                                  )
                                : Column(
                                    children: [
                                      _DirectoryHeaderRow(
                                        providerActive:
                                            _providerFilters.isNotEmpty,
                                        catalogContactActive:
                                            _catalogContactFilters.isNotEmpty,
                                        operationalContactActive:
                                            _operationalContactFilters
                                                .isNotEmpty,
                                        phoneActive: _phoneFilters.isNotEmpty,
                                        locationActive:
                                            _locationFilters.isNotEmpty,
                                        hasContainersActive:
                                            _hasContainersFilter != null,
                                        creditActive: _hasCreditFilter != null,
                                        paymentStageActive:
                                            _paymentStageFilter != null,
                                        onProviderFilter: _pickProviderFilter,
                                        onCatalogContactFilter:
                                            _pickCatalogContactFilter,
                                        onOperationalContactFilter:
                                            _pickOperationalContactFilter,
                                        onPhoneFilter: _pickPhoneFilter,
                                        onLocationFilter: _pickLocationFilter,
                                        onContainersFilter:
                                            _pickContainersFilter,
                                        onCreditFilter: _pickCreditFilter,
                                        onPaymentStageFilter:
                                            _pickPaymentStageFilter,
                                      ),
                                      const SizedBox(height: 10),
                                      Expanded(
                                        child: ListView.separated(
                                          itemCount: visibleRows.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 8),
                                          itemBuilder: (context, index) {
                                            final row = visibleRows[index];
                                            return _DirectoryDataRow(
                                              row: row,
                                              selected:
                                                  _selectedProviderId ==
                                                  row.providerId,
                                              onTap: () {
                                                setState(
                                                  () => _selectedProviderId =
                                                      row.providerId,
                                                );
                                              },
                                              onEdit: () => _editRow(row),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectoryDialogField extends StatelessWidget {
  final double width;
  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final bool enabled;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _DirectoryDialogField({
    required this.width,
    required this.label,
    required this.controller,
    this.readOnly = false,
    this.enabled = true,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        enabled: enabled,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        cursorColor: comprasAreaTokens.primaryStrong,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: enabled
              ? comprasAreaTokens.onGlass
              : comprasAreaTokens.badgeText.withValues(alpha: 0.72),
        ),
        decoration: _directoryFieldDecoration(label: label),
      ),
    );
  }
}

class _ProviderDirectoryEditDialog extends StatefulWidget {
  final ComprasProviderDirectoryRecord row;

  const _ProviderDirectoryEditDialog({required this.row});

  @override
  State<_ProviderDirectoryEditDialog> createState() =>
      _ProviderDirectoryEditDialogState();
}

class _ProviderDirectoryEditDialogState
    extends State<_ProviderDirectoryEditDialog> {
  late final TextEditingController _catalogContactC;
  late final TextEditingController _operationalContactC;
  late final TextEditingController _phoneC;
  late final TextEditingController _locationC;
  late final TextEditingController _containerCountC;
  late final TextEditingController _creditDaysC;
  late final TextEditingController _paymentNotesC;
  late bool _hasContainers;
  late String _paymentStage;

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    _catalogContactC = TextEditingController(text: row.catalogContact);
    _operationalContactC = TextEditingController(text: row.operationalContact);
    _phoneC = TextEditingController(text: row.phone);
    _locationC = TextEditingController(text: row.location);
    _containerCountC = TextEditingController(
      text: row.containerCount == 0 ? '' : row.containerCount.toString(),
    );
    _creditDaysC = TextEditingController(
      text: row.creditDays == 0 ? '' : row.creditDays.toString(),
    );
    _paymentNotesC = TextEditingController(text: row.paymentNotes);
    _hasContainers = row.hasContainers;
    _paymentStage = row.paymentStage;
  }

  @override
  void dispose() {
    _catalogContactC.dispose();
    _operationalContactC.dispose();
    _phoneC.dispose();
    _locationC.dispose();
    _containerCountC.dispose();
    _creditDaysC.dispose();
    _paymentNotesC.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      widget.row.copyWith(
        operationalContact: _operationalContactC.text.trim(),
        phone: _phoneC.text.trim(),
        location: _locationC.text.trim(),
        hasContainers: _hasContainers,
        containerCount: _hasContainers
            ? int.tryParse(_containerCountC.text.trim()) ?? 0
            : 0,
        creditDays: int.tryParse(_creditDaysC.text.trim()) ?? 0,
        paymentStage: _paymentStage,
        paymentNotes: _paymentNotesC.text.trim(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return AreaThemeScope(
      tokens: comprasAreaTokens,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ContractGlassCard(
            borderRadius: BorderRadius.circular(26),
            padding: EdgeInsets.zero,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: comprasAreaTokens.fieldSurface.withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        row.providerName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: comprasAreaTokens.onGlass,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ficha operativa para compras y finanzas.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: comprasAreaTokens.badgeText.withValues(
                            alpha: 0.92,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _DirectoryDialogField(
                            width: 340,
                            label: 'Contacto catálogo',
                            readOnly: true,
                            controller: _catalogContactC,
                          ),
                          _DirectoryDialogField(
                            width: 340,
                            label: 'Contacto operativo',
                            controller: _operationalContactC,
                          ),
                          _DirectoryDialogField(
                            width: 340,
                            label: 'Teléfono',
                            controller: _phoneC,
                            keyboardType: TextInputType.phone,
                          ),
                          _DirectoryDialogField(
                            width: 340,
                            label: 'Ubicación',
                            controller: _locationC,
                          ),
                          _DirectoryDialogField(
                            width: 164,
                            label: 'Días de crédito',
                            controller: _creditDaysC,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SwitchListTile(
                                  value: _hasContainers,
                                  contentPadding: EdgeInsets.zero,
                                  activeThumbColor:
                                      comprasAreaTokens.primaryStrong,
                                  title: Text(
                                    'Usa contenedores',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: comprasAreaTokens.onGlass,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Activa esto solo si al proveedor se le asignan contenedores.',
                                    style: TextStyle(
                                      color: comprasAreaTokens.badgeText,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _hasContainers = value;
                                      if (!value) {
                                        _containerCountC.text = '';
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: 6),
                                _DirectoryDialogField(
                                  width: 220,
                                  label: 'Cantidad',
                                  controller: _containerCountC,
                                  enabled: _hasContainers,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Situación de pago',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: comprasAreaTokens.onGlass,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final option in _kPaymentStageOptions)
                                      _PaymentStageChoiceChip(
                                        stage: option,
                                        label: _paymentStageLabel(option),
                                        selected: _paymentStage == option,
                                        onTap: () {
                                          setState(
                                            () => _paymentStage = option,
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _paymentNotesC,
                        minLines: 3,
                        maxLines: 5,
                        cursorColor: comprasAreaTokens.primaryStrong,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: comprasAreaTokens.onGlass,
                        ),
                        decoration: _directoryFieldDecoration(
                          label: 'Notas de pago / convenio / urgencia',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: contractSecondaryButtonStyle(context),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            style: contractPrimaryButtonStyle(context),
                            onPressed: _save,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Guardar'),
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
}

InputDecoration _directoryFieldDecoration({required String label}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      color: comprasAreaTokens.onGlass.withValues(alpha: 0.74),
    ),
    filled: true,
    fillColor: comprasAreaTokens.fieldSurface.withValues(alpha: 0.92),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: comprasAreaTokens.primary, width: 1.4),
    ),
  );
}

class _DirectorySurface extends StatelessWidget {
  final Widget child;

  const _DirectorySurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ContractGlassCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: child,
      ),
    );
  }
}

class _DirectoryFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DirectoryFilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? tokens.accent.withValues(alpha: 0.90)
                : tokens.fieldSurface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? tokens.primaryStrong.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: active ? const Color(0xFF0B0E12) : tokens.onGlass,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentStageChoiceChip extends StatelessWidget {
  final String stage;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentStageChoiceChip({
    required this.stage,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = _paymentStageTone(stage);
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? tone.withValues(alpha: 0.14)
                : tokens.fieldSurface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? tone.withValues(alpha: 0.48)
                  : tokens.border.withValues(alpha: 0.78),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? tone : tokens.onGlass,
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectoryFilterSummary extends StatelessWidget {
  final List<String> labels;
  final VoidCallback? onClearAll;

  const _DirectoryFilterSummary({required this.labels, this.onClearAll});

  static bool hasSpacing(
    String searchQuery,
    bool? hasContainersFilter,
    String? paymentStageFilter,
  ) {
    return searchQuery.trim().isNotEmpty ||
        hasContainersFilter != null ||
        paymentStageFilter != null;
  }

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
              color: comprasAreaTokens.badgeBackground.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: comprasAreaTokens.border.withValues(alpha: 0.70),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: comprasAreaTokens.onGlass,
              ),
            ),
          ),
        if (onClearAll != null)
          OutlinedButton.icon(
            style: contractSecondaryButtonStyle(context),
            onPressed: onClearAll,
            icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
            label: const Text('Limpiar filtros'),
          ),
      ],
    );
  }
}

class _DirectoryHeaderRow extends StatelessWidget {
  final bool providerActive;
  final bool catalogContactActive;
  final bool operationalContactActive;
  final bool phoneActive;
  final bool locationActive;
  final bool hasContainersActive;
  final bool creditActive;
  final bool paymentStageActive;
  final Future<void> Function() onProviderFilter;
  final Future<void> Function() onCatalogContactFilter;
  final Future<void> Function() onOperationalContactFilter;
  final Future<void> Function() onPhoneFilter;
  final Future<void> Function() onLocationFilter;
  final Future<void> Function() onContainersFilter;
  final Future<void> Function() onCreditFilter;
  final Future<void> Function() onPaymentStageFilter;

  const _DirectoryHeaderRow({
    required this.providerActive,
    required this.catalogContactActive,
    required this.operationalContactActive,
    required this.phoneActive,
    required this.locationActive,
    required this.hasContainersActive,
    required this.creditActive,
    required this.paymentStageActive,
    required this.onProviderFilter,
    required this.onCatalogContactFilter,
    required this.onOperationalContactFilter,
    required this.onPhoneFilter,
    required this.onLocationFilter,
    required this.onContainersFilter,
    required this.onCreditFilter,
    required this.onPaymentStageFilter,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final columns = [
      _DirectoryHeaderColumn(
        'Proveedor',
        _kDirProviderW,
        onFilter: () => unawaited(onProviderFilter()),
        active: providerActive,
      ),
      _DirectoryHeaderColumn(
        'Contacto catálogo',
        _kDirCatalogContactW,
        onFilter: () => unawaited(onCatalogContactFilter()),
        active: catalogContactActive,
      ),
      _DirectoryHeaderColumn(
        'Contacto operativo',
        _kDirOperationalContactW,
        onFilter: () => unawaited(onOperationalContactFilter()),
        active: operationalContactActive,
      ),
      _DirectoryHeaderColumn(
        'Teléfono',
        _kDirPhoneW,
        onFilter: () => unawaited(onPhoneFilter()),
        active: phoneActive,
      ),
      _DirectoryHeaderColumn(
        'Ubicación',
        _kDirLocationW,
        onFilter: () => unawaited(onLocationFilter()),
        active: locationActive,
      ),
      _DirectoryHeaderColumn(
        'Contenedores',
        _kDirContainersW,
        onFilter: () => unawaited(onContainersFilter()),
        active: hasContainersActive,
      ),
      const _DirectoryHeaderColumn('Cantidad', _kDirContainerCountW),
      _DirectoryHeaderColumn(
        'Crédito',
        _kDirCreditDaysW,
        onFilter: () => unawaited(onCreditFilter()),
        active: creditActive,
      ),
      _DirectoryHeaderColumn(
        'Situación pago',
        _kDirPaymentStageW,
        onFilter: () => unawaited(onPaymentStageFilter()),
        active: paymentStageActive,
      ),
      const _DirectoryHeaderColumn('Notas de pago', _kDirNotesW),
    ];
    return Card(
      elevation: 0,
      color: Colors.black.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: ContractGridScaledRow(
          child: SizedBox(
            width: _kDirContentW + _kDirActionsW,
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
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: tokens.badgeText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: _kDirActionsW),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectoryHeaderColumn {
  final String label;
  final double width;
  final VoidCallback? onFilter;
  final bool active;

  const _DirectoryHeaderColumn(
    this.label,
    this.width, {
    this.onFilter,
    this.active = false,
  });
}

class _DirectoryDataRow extends StatefulWidget {
  final ComprasProviderDirectoryRecord row;
  final bool selected;
  final VoidCallback onTap;
  final Future<void> Function() onEdit;

  const _DirectoryDataRow({
    required this.row,
    required this.selected,
    required this.onTap,
    required this.onEdit,
  });

  @override
  State<_DirectoryDataRow> createState() => _DirectoryDataRowState();
}

class _DirectoryDataRowState extends State<_DirectoryDataRow> {
  bool _hovering = false;

  Future<void> _openContextMenuAt(Offset globalPosition) async {
    final action = await showMenu<_DirectoryRowMenuAction>(
      context: context,
      color: comprasAreaTokens.fieldSurface.withValues(alpha: 0.96),
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: comprasAreaTokens.border.withValues(alpha: 0.78),
        ),
      ),
      items: [
        PopupMenuItem<_DirectoryRowMenuAction>(
          value: _DirectoryRowMenuAction(
            label: 'Editar ficha',
            icon: Icons.edit_rounded,
            onTap: () => unawaited(widget.onEdit()),
          ),
          child: Row(
            children: [
              Icon(
                Icons.edit_rounded,
                color: comprasAreaTokens.primaryStrong,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'Editar ficha',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: comprasAreaTokens.onGlass,
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
    final row = widget.row;
    final selected = widget.selected;
    final fill = selected
        ? tokens.primarySoft.withValues(alpha: 0.82)
        : _hovering
        ? tokens.glassSurface.withValues(alpha: 0.90)
        : tokens.fieldSurface.withValues(alpha: 0.76);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Card(
        elevation: 0,
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected
                ? tokens.primaryStrong.withValues(alpha: 0.40)
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
                        onDoubleTap: () => unawaited(widget.onEdit()),
                        child: SizedBox(
                          width: _kDirContentW + _kDirActionsW,
                          child: Row(
                            children: [
                              _DirectoryCell(
                                width: _kDirProviderW,
                                child: _DirectoryProviderBlock(row: row),
                              ),
                              _DirectoryCell(
                                width: _kDirCatalogContactW,
                                text: row.catalogContact.isEmpty
                                    ? '—'
                                    : row.catalogContact,
                              ),
                              _DirectoryCell(
                                width: _kDirOperationalContactW,
                                text: row.operationalContact.isEmpty
                                    ? '—'
                                    : row.operationalContact,
                              ),
                              _DirectoryCell(
                                width: _kDirPhoneW,
                                text: row.phone.isEmpty ? '—' : row.phone,
                              ),
                              _DirectoryCell(
                                width: _kDirLocationW,
                                text: row.location.isEmpty ? '—' : row.location,
                              ),
                              _DirectoryCell(
                                width: _kDirContainersW,
                                child: _DirectoryBadge(
                                  label: row.hasContainers ? 'SI' : 'NO',
                                  active: row.hasContainers,
                                ),
                              ),
                              _DirectoryCell(
                                width: _kDirContainerCountW,
                                text: row.hasContainers
                                    ? '${row.containerCount}'
                                    : '0',
                                alignEnd: true,
                              ),
                              _DirectoryCell(
                                width: _kDirCreditDaysW,
                                text: row.creditDays > 0
                                    ? '${row.creditDays} días'
                                    : 'Sin crédito',
                              ),
                              _DirectoryCell(
                                width: _kDirPaymentStageW,
                                child: _DirectoryBadge(
                                  label: _paymentStageLabel(row.paymentStage),
                                  active: row.paymentStage != 'AL_CORRIENTE',
                                  tone: _paymentStageTone(row.paymentStage),
                                ),
                              ),
                              _DirectoryCell(
                                width: _kDirNotesW,
                                text: row.paymentNotes.isEmpty
                                    ? '—'
                                    : row.paymentNotes,
                              ),
                              AnchoredActionSlot(
                                width: _kDirActionsW,
                                trailingWidth: 36,
                                leading: const SizedBox.shrink(),
                                trailing:
                                    PopupMenuButton<_DirectoryRowMenuAction>(
                                      tooltip: 'Acciones',
                                      padding: EdgeInsets.zero,
                                      color: comprasAreaTokens.fieldSurface
                                          .withValues(alpha: 0.98),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: tokens.border.withValues(
                                            alpha: 0.78,
                                          ),
                                        ),
                                      ),
                                      onSelected: (item) => item.onTap(),
                                      itemBuilder: (context) => [
                                        PopupMenuItem<_DirectoryRowMenuAction>(
                                          value: _DirectoryRowMenuAction(
                                            label: 'Editar ficha',
                                            icon: Icons.edit_rounded,
                                            onTap: () =>
                                                unawaited(widget.onEdit()),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.edit_rounded,
                                                color: comprasAreaTokens
                                                    .primaryStrong,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'Editar ficha',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      comprasAreaTokens.onGlass,
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
                                          color: const Color(
                                            0xFF171C22,
                                          ).withValues(alpha: 0.96),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: tokens.border.withValues(
                                              alpha: 0.78,
                                            ),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              blurRadius: 12,
                                              offset: const Offset(0, 5),
                                              color: Colors.black.withValues(
                                                alpha: 0.16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.more_horiz_rounded,
                                            color: Colors.white,
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
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DirectoryRowMenuAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DirectoryRowMenuAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class _DirectoryProviderBlock extends StatelessWidget {
  final ComprasProviderDirectoryRecord row;

  const _DirectoryProviderBlock({required this.row});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          row.providerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: tokens.onGlass,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          row.providerCode,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: tokens.badgeText,
          ),
        ),
      ],
    );
  }
}

class _DirectoryCell extends StatelessWidget {
  final double width;
  final String? text;
  final Widget? child;
  final bool alignEnd;

  const _DirectoryCell({
    required this.width,
    this.text,
    this.child,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final content =
        child ??
        Text(
          text ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: comprasAreaTokens.onGlass,
            height: 1.15,
          ),
        );
    return SizedBox(
      width: width,
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: content,
        ),
      ),
    );
  }
}

class _DirectoryBadge extends StatelessWidget {
  final String label;
  final bool active;
  final Color? tone;

  const _DirectoryBadge({required this.label, required this.active, this.tone});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final resolvedTone = tone ?? tokens.primaryStrong;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active
            ? resolvedTone.withValues(alpha: 0.10)
            : tokens.badgeBackground.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? resolvedTone.withValues(alpha: 0.24)
              : tokens.border.withValues(alpha: 0.70),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: active ? resolvedTone : tokens.badgeText,
        ),
      ),
    );
  }
}

class _DirectoryFilterOption<T> {
  final T value;
  final String label;

  const _DirectoryFilterOption({required this.value, required this.label});
}

Future<T?> _showDirectorySingleSelectDialog<T>(
  BuildContext context, {
  required String title,
  required List<_DirectoryFilterOption<T>> options,
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (searchFocus.canRequestFocus) {
          searchFocus.requestFocus();
        }
      });

      return StatefulBuilder(
        builder: (context, setLocalState) {
          final filtered = options
              .where((option) {
                final normalizedQuery = query.trim().toUpperCase();
                if (normalizedQuery.isEmpty) return true;
                return option.label.toUpperCase().contains(normalizedQuery);
              })
              .toList(growable: false);

          while (itemFocusNodes.length < filtered.length) {
            itemFocusNodes.add(FocusNode());
          }
          while (itemFocusNodes.length > filtered.length) {
            itemFocusNodes.removeLast().dispose();
          }

          return Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.of(dialogContext).pop();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                  filtered.isNotEmpty) {
                itemFocusNodes.first.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: AreaThemeScope(
              tokens: comprasAreaTokens,
              child: Dialog(
                backgroundColor: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                    maxHeight: 560,
                  ),
                  child: ContractGlassCard(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: comprasAreaTokens.primaryStrong,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                            cursorColor: comprasAreaTokens.primaryStrong,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: comprasAreaTokens.onGlass,
                            ),
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
                              style: TextButton.styleFrom(
                                foregroundColor: comprasAreaTokens.onGlass,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              child: const Text('Limpiar selección'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Text(
                                    'Sin resultados',
                                    style: TextStyle(
                                      color: comprasAreaTokens.badgeText,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
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
                                      child: _DirectoryPickerOptionTile(
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

Future<Set<T>?> _showDirectoryMultiSelectDialog<T>(
  BuildContext context, {
  required String title,
  required List<_DirectoryFilterOption<T>> options,
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (searchFocus.canRequestFocus) {
          searchFocus.requestFocus();
        }
      });

      return StatefulBuilder(
        builder: (context, setLocalState) {
          final filtered = options
              .where(
                (option) =>
                    option.label.toLowerCase().contains(query.toLowerCase()),
              )
              .toList(growable: false);

          while (itemFocusNodes.length < filtered.length) {
            itemFocusNodes.add(FocusNode());
          }
          while (itemFocusNodes.length > filtered.length) {
            itemFocusNodes.removeLast().dispose();
          }

          return AreaThemeScope(
            tokens: comprasAreaTokens,
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
                            color: comprasAreaTokens.primaryStrong,
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
                                      child: _DirectoryPickerOptionTile(
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

class _DirectoryPickerOptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  const _DirectoryPickerOptionTile({
    required this.label,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? comprasAreaTokens.badgeBackground.withValues(alpha: 0.76)
        : highlighted
        ? comprasAreaTokens.glassSurface.withValues(alpha: 0.82)
        : comprasAreaTokens.fieldSurface.withValues(alpha: 0.72);
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
                      color: kComprasInk,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: comprasAreaTokens.primaryStrong,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectoryEmptyState extends StatelessWidget {
  final bool hasActiveFilters;
  final Future<void> Function() onReload;
  final VoidCallback? onClearFilters;

  const _DirectoryEmptyState({
    required this.hasActiveFilters,
    required this.onReload,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.badge_outlined, size: 44, color: kComprasMutedInk),
            const SizedBox(height: 12),
            Text(
              hasActiveFilters
                  ? 'No hubo coincidencias para los filtros activos.'
                  : 'No hay proveedores visibles todavía.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kComprasInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveFilters
                  ? 'Prueba limpiando o ajustando los filtros por columna.'
                  : 'Sincroniza catálogo o agrega proveedores desde Catálogo Compras.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kComprasMutedInk,
              ),
            ),
            if (onClearFilters != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                style: contractSecondaryButtonStyle(context),
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Limpiar filtros'),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => unawaited(onReload()),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Recargar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComprasDirectoryBackground extends StatelessWidget {
  const _ComprasDirectoryBackground();

  @override
  Widget build(BuildContext context) {
    return const ComprasAreaBackground();
  }
}

class _ComprasDirectoryHeaderBrand extends StatelessWidget {
  const _ComprasDirectoryHeaderBrand();

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
        const Text(
          'Directorio',
          maxLines: 1,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.25,
            height: 1.0,
            color: Color(0xFFE6DBD8),
          ),
        ),
      ],
    );
  }
}

class _ComprasDirectorySidePanel extends StatelessWidget {
  final bool canReturnToDirection;
  final bool canAccessFinanzasArea;
  final ValueChanged<String> onNavigate;

  const _ComprasDirectorySidePanel({
    required this.canReturnToDirection,
    required this.canAccessFinanzasArea,
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
                'Compras Mayoreo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              if (canReturnToDirection) ...[
                _DirectorySideNavItem(
                  icon: Icons.arrow_back_rounded,
                  title: 'Volver a Dirección',
                  onTap: () async => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 10),
              ],
              const _DirectorySectionHeader(label: 'AREA'),
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
                    _DirectorySideNavItem(
                      icon: Icons.confirmation_number_outlined,
                      title: 'Tickets Compras',
                      subtitle: 'Captura y seguimiento operativo',
                      onTap: () async => onNavigate('Tickets Compras'),
                    ),
                    const SizedBox(height: 8),
                    _DirectorySideNavItem(
                      icon: Icons.tune_rounded,
                      title: 'Ajuste de precios',
                      subtitle: 'Vigentes e historial',
                      onTap: () async => onNavigate('Ajuste de precios'),
                    ),
                    const SizedBox(height: 8),
                    _DirectorySideNavItem(
                      icon: Icons.price_check_rounded,
                      title: 'Catálogo Compras',
                      subtitle: 'Proveedores, materiales y precios',
                      onTap: () async => onNavigate('Catálogo Compras'),
                    ),
                    const SizedBox(height: 8),
                    _DirectorySideNavItem(
                      icon: Icons.badge_rounded,
                      title: 'Directorio Proveedores',
                      subtitle: 'Crédito, contacto y operación',
                      accented: true,
                      onTap: () async {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _DirectorySectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              _DirectorySideNavItem(
                icon: Icons.shopping_cart_checkout_rounded,
                title: 'Dashboard Compras',
                subtitle: 'Tickets y operación de compra',
                onTap: () async => onNavigate('Dashboard Compras'),
              ),
              if (canAccessFinanzasArea) const SizedBox(height: 8),
              if (canAccessFinanzasArea)
                _DirectorySideNavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Dashboard Finanzas',
                  subtitle: 'Pagos, liquidez y compromisos',
                  onTap: () async => onNavigate('Dashboard Finanzas'),
                ),
              if (canReturnToDirection) const SizedBox(height: 8),
              if (canReturnToDirection)
                _DirectorySideNavItem(
                  icon: Icons.assessment_outlined,
                  title: 'Dashboard Dirección',
                  subtitle: 'Vista ejecutiva multiarea',
                  onTap: () async => onNavigate('Dashboard Dirección'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectorySectionHeader extends StatelessWidget {
  final String label;

  const _DirectorySectionHeader({required this.label});

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

class _DirectorySideNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool accented;
  final Future<void> Function() onTap;

  const _DirectorySideNavItem({
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
            gradient: accented ? kComprasPanelGradient : null,
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

class _DirectoryHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _DirectoryHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_DirectoryHeaderButton> createState() => _DirectoryHeaderButtonState();
}

class _DirectoryHeaderButtonState extends State<_DirectoryHeaderButton> {
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
