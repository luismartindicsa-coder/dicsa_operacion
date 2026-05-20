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
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/csv_file_save.dart';
import 'compras_catalog_page.dart';
import 'compras_dashboard_page.dart';
import 'compras_provider_directory_store.dart';
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
      return const Color(0xFF7A1914);
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
  bool _menuOpen = false;
  bool _loading = true;
  bool _exportingCsv = false;
  bool _saving = false;
  String _searchQuery = '';
  bool? _hasContainersFilter;
  String? _paymentStageFilter;
  String? _selectedProviderId;
  late final TextEditingController _searchC;
  List<ComprasProviderDirectoryRecord> _rows =
      <ComprasProviderDirectoryRecord>[];

  @override
  void initState() {
    super.initState();
    _searchC = TextEditingController();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadDirectory());
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
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
      case 'Dashboard Finanzas':
        unawaited(_openFinanzas());
        return;
      case 'Directorio Proveedores':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
    }
  }

  List<ComprasProviderDirectoryRecord> get _visibleRows {
    final query = _searchQuery.trim().toUpperCase();
    return _rows
        .where((row) {
          if (query.isNotEmpty) {
            final haystack = [
              row.providerName,
              row.catalogContact,
              row.operationalContact,
              row.phone,
              row.location,
              row.paymentNotes,
            ].join(' ').toUpperCase();
            if (!haystack.contains(query)) return false;
          }
          if (_hasContainersFilter != null &&
              row.hasContainers != _hasContainersFilter) {
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
    setState(() => _saving = true);
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
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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

  void _cyclePaymentStageFilter() {
    setState(() {
      if (_paymentStageFilter == null) {
        _paymentStageFilter = _kPaymentStageOptions.first;
        return;
      }
      final currentIndex = _kPaymentStageOptions.indexOf(_paymentStageFilter!);
      if (currentIndex == -1 ||
          currentIndex == _kPaymentStageOptions.length - 1) {
        _paymentStageFilter = null;
        return;
      }
      _paymentStageFilter = _kPaymentStageOptions[currentIndex + 1];
    });
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
          leadingBuilder: (_, _) => _DirectoryHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => const _ComprasDirectoryHeaderBrand(),
          trailingBuilder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DirectoryHeaderButton(
                label: 'Catálogo',
                icon: Icons.price_check_rounded,
                onTap: _openCatalog,
              ),
              const SizedBox(width: 10),
              _DirectoryHeaderButton(
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
                  child: _ComprasDirectorySidePanel(
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              SizedBox(
                                width: 320,
                                child: TextField(
                                  controller: _searchC,
                                  onChanged: (value) =>
                                      setState(() => _searchQuery = value),
                                  decoration:
                                      _directoryFieldDecoration(
                                        label:
                                            'Buscar proveedor, teléfono o nota',
                                      ).copyWith(
                                        prefixIcon: const Icon(
                                          Icons.search_rounded,
                                        ),
                                      ),
                                ),
                              ),
                              _DirectoryFilterChip(
                                label: _hasContainersFilter == true
                                    ? 'Con contenedores'
                                    : _hasContainersFilter == false
                                    ? 'Sin contenedores'
                                    : 'Contenedores',
                                active: _hasContainersFilter != null,
                                onTap: () {
                                  setState(() {
                                    _hasContainersFilter =
                                        _hasContainersFilter == null
                                        ? true
                                        : _hasContainersFilter == true
                                        ? false
                                        : null;
                                  });
                                },
                              ),
                              _DirectoryFilterChip(
                                label: _paymentStageFilter == null
                                    ? 'Situación pago'
                                    : _paymentStageLabel(_paymentStageFilter!),
                                active: _paymentStageFilter != null,
                                onTap: _cyclePaymentStageFilter,
                              ),
                              OutlinedButton.icon(
                                onPressed: _saving ? null : _loadDirectory,
                                icon: const Icon(Icons.sync_rounded),
                                label: const Text('Sincronizar catálogo'),
                              ),
                              if (_searchQuery.isNotEmpty ||
                                  _hasContainersFilter != null ||
                                  _paymentStageFilter != null)
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _searchC.clear();
                                      _hasContainersFilter = null;
                                      _paymentStageFilter = null;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.filter_alt_off_rounded,
                                  ),
                                  label: const Text('Limpiar'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _DirectoryFilterSummary(
                            labels: [
                              if (_searchQuery.trim().isNotEmpty)
                                'Busqueda: ${_searchQuery.trim()}',
                              if (_hasContainersFilter == true)
                                'Con contenedores',
                              if (_hasContainersFilter == false)
                                'Sin contenedores',
                              if (_paymentStageFilter != null)
                                'Situación: ${_paymentStageLabel(_paymentStageFilter!)}',
                            ],
                          ),
                          if (_DirectoryFilterSummary.hasSpacing(
                            _searchQuery,
                            _hasContainersFilter,
                            _paymentStageFilter,
                          ))
                            const SizedBox(height: 14),
                          Expanded(
                            child: _loading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : visibleRows.isEmpty
                                ? _DirectoryEmptyState(
                                    searchQuery: _searchQuery,
                                    onReload: _loadDirectory,
                                  )
                                : Column(
                                    children: [
                                      const _DirectoryHeaderRow(),
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ContractGlassCard(
          borderRadius: BorderRadius.circular(26),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.providerName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: kComprasInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ficha operativa para compras y finanzas.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kComprasMutedInk.withValues(alpha: 0.92),
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
                            title: const Text(
                              'Usa contenedores',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: const Text(
                              'Activa esto solo si al proveedor se le asignan contenedores.',
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
                          const Text(
                            'Situación de pago',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: kComprasInk,
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
                                    setState(() => _paymentStage = option);
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
                  decoration: _directoryFieldDecoration(
                    label: 'Notas de pago / convenio / urgencia',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
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
    );
  }
}

InputDecoration _directoryFieldDecoration({required String label}) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.90),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: comprasAreaTokens.border.withValues(alpha: 0.7),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF9C211B), width: 1.4),
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
                ? tokens.primaryStrong.withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? tokens.primaryStrong
                  : comprasAreaTokens.border.withValues(alpha: 0.72),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : kComprasInk,
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
                : Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? tone.withValues(alpha: 0.48)
                  : comprasAreaTokens.border.withValues(alpha: 0.72),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? tone : kComprasInk,
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectoryFilterSummary extends StatelessWidget {
  final List<String> labels;

  const _DirectoryFilterSummary({required this.labels});

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
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: kComprasInk,
              ),
            ),
          ),
      ],
    );
  }
}

class _DirectoryHeaderRow extends StatelessWidget {
  const _DirectoryHeaderRow();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final columns = const [
      _DirectoryHeaderColumn('Proveedor', _kDirProviderW),
      _DirectoryHeaderColumn('Contacto catálogo', _kDirCatalogContactW),
      _DirectoryHeaderColumn('Contacto operativo', _kDirOperationalContactW),
      _DirectoryHeaderColumn('Teléfono', _kDirPhoneW),
      _DirectoryHeaderColumn('Ubicación', _kDirLocationW),
      _DirectoryHeaderColumn('Contenedores', _kDirContainersW),
      _DirectoryHeaderColumn('Cantidad', _kDirContainerCountW),
      _DirectoryHeaderColumn('Crédito', _kDirCreditDaysW),
      _DirectoryHeaderColumn('Situación pago', _kDirPaymentStageW),
      _DirectoryHeaderColumn('Notas de pago', _kDirNotesW),
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

  const _DirectoryHeaderColumn(this.label, this.width);
}

class _DirectoryDataRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final fill = selected
        ? tokens.primarySoft.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.84);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onDoubleTap: () => unawaited(onEdit()),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? tokens.primaryStrong.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.72),
            ),
          ),
          child: ContractGridScaledRow(
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
                    text: row.catalogContact.isEmpty ? '—' : row.catalogContact,
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
                    text: row.hasContainers ? '${row.containerCount}' : '0',
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
                    text: row.paymentNotes.isEmpty ? '—' : row.paymentNotes,
                  ),
                  SizedBox(
                    width: _kDirActionsW,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        onPressed: () => unawaited(onEdit()),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Editar'),
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
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: kComprasInk,
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
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: kComprasInk,
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

class _DirectoryEmptyState extends StatelessWidget {
  final String searchQuery;
  final Future<void> Function() onReload;

  const _DirectoryEmptyState({
    required this.searchQuery,
    required this.onReload,
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
              searchQuery.trim().isEmpty
                  ? 'No hay proveedores visibles todavía.'
                  : 'No hubo coincidencias para tu búsqueda.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kComprasInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.trim().isEmpty
                  ? 'Sincroniza catálogo o agrega proveedores desde Catálogo Compras.'
                  : 'Prueba con otro nombre, teléfono o limpia los filtros activos.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kComprasMutedInk,
              ),
            ),
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
    final tokens = AreaThemeScope.of(context);
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF181010),
                const Color(0xFF241515),
                tokens.accent.withValues(alpha: 0.38),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ],
    );
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
  final ValueChanged<String> onNavigate;

  const _ComprasDirectorySidePanel({
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
                      icon: Icons.shopping_cart_checkout_rounded,
                      title: 'Dashboard Compras',
                      subtitle: 'Tickets y operación de compra',
                      onTap: () async => onNavigate('Dashboard Compras'),
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
              if (canReturnToDirection) ...[
                _DirectorySideNavItem(
                  icon: Icons.assessment_outlined,
                  title: 'Dashboard Dirección',
                  subtitle: 'Vista ejecutiva multiarea',
                  onTap: () async => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 8),
              ],
              _DirectorySideNavItem(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Dashboard Finanzas',
                subtitle: 'Pagos, liquidez y compromisos',
                onTap: () async => onNavigate('Dashboard Finanzas'),
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
