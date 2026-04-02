// ignore_for_file: unused_element, unused_field

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/dashboard_page.dart';
import '../dashboard/general_dashboard_page.dart';
import '../maintenance/maintenance_page.dart';
import '../shared/page_routes.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/ui_contract_core/dialogs/confirm_dialog_key_handler.dart';
import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/contract_tokens.dart';
import '../shared/utils/csv_file_save.dart';
import 'inventory_movements_grid.dart';
import 'inventory_stock_v2_body.dart';
import 'inventory_transformation_grid.dart';
import 'services_page.dart';
import 'warehouse_page.dart';
import 'weighings_page.dart';
import 'services_shell.dart';

const List<_MaterialOption> _kInventoryMaterials = [
  _MaterialOption('CARDBOARD_BULK_NATIONAL', 'Carton granel'),
  _MaterialOption('BALE_NATIONAL', 'Paca nacional'),
  _MaterialOption('BALE_AMERICAN', 'Paca americana'),
  _MaterialOption('BALE_CLEAN', 'Paca limpia'),
  _MaterialOption('BALE_TRASH', 'Paca basura'),
  _MaterialOption('CAPLE', 'Caple'),
  _MaterialOption('SCRAP', 'Chatarra'),
  _MaterialOption('METAL', 'Metal'),
  _MaterialOption('WOOD', 'Madera'),
  _MaterialOption('PAPER', 'Papel'),
  _MaterialOption('PLASTIC', 'Plástico'),
];

const String _kFixedInventorySite = 'DICSA_CELAYA';

const ContractAreaTokens _kOperationsAreaTokens = ContractAreaTokens(
  primary: Color(0xFF1E8E63),
  primaryStrong: Color(0xFF0B2B2B),
  primarySoft: Color(0xFFD8EFE8),
  accent: Color(0xFF52CFA6),
  surfaceTint: Color(0xFFEAF7F2),
  border: Color(0xFFB7D7D2),
  badgeBackground: Color(0xFFDDF4EC),
  badgeText: Color(0xFF0D5C46),
  glow: Color(0xFF6CB7E2),
);

const List<_MaterialOption> _kInventorySummaryMaterials = [
  _MaterialOption('CARDBOARD_BULK_NATIONAL', 'Carton granel'),
  _MaterialOption('BALE_NATIONAL', 'Paca nacional'),
  _MaterialOption('BALE_AMERICAN', 'Paca americana'),
  _MaterialOption('BALE_CLEAN', 'Paca limpia'),
  _MaterialOption('BALE_TRASH', 'Paca basura'),
  _MaterialOption('CAPLE', 'Caple'),
  _MaterialOption('SCRAP', 'Chatarra'),
  _MaterialOption('METAL', 'Metal'),
  _MaterialOption('WOOD', 'Madera'),
  _MaterialOption('PAPER', 'Papel'),
  _MaterialOption('PLASTIC', 'Plástico'),
];

class _GuideSectionData {
  final String heading;
  final List<String> lines;

  const _GuideSectionData({required this.heading, required this.lines});
}

Future<void> _showModuleGuideDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<_GuideSectionData> sections,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) => ContractDialogShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: SizedBox(
          width: 760,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF17324A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A4B49),
                ),
              ),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final section in sections) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.56),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section.heading,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF17324A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final line in section.lines)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    line,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2A4B49),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: contractPrimaryButtonStyle(dialogContext),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showProductionUsageGuideDialog(BuildContext context) {
  return _showModuleGuideDialog(
    context,
    title: 'Instructivo de uso',
    subtitle: 'Producción',
    sections: const [
      _GuideSectionData(
        heading: 'Para qué sirve',
        lines: [
          'Esta pantalla registra la producción o clasificación que realmente salió a patio.',
          'Producción no registra compras ni ventas: solo transforma material base en material clasificado.',
        ],
      ),
      _GuideSectionData(
        heading: 'Flujo operativo',
        lines: [
          'Primero una entrada suma al inventario general, por ejemplo CARTÓN o PAPEL.',
          'Después Producción baja ese inventario general y sube el material clasificado en patio.',
          'Finalmente una venta descuenta del material clasificado, no del material general.',
        ],
      ),
      _GuideSectionData(
        heading: 'Cómo capturar una fila',
        lines: [
          'Selecciona la fecha, el turno, el origen y el material clasificado que salió a patio.',
          'Captura siempre los kg de salida. Las unidades o pacas se llenan solo cuando aplican.',
          'El comentario sirve para anotar aclaraciones operativas del movimiento.',
        ],
      ),
      _GuideSectionData(
        heading: 'Qué significa Consumo',
        lines: [
          'Consumo es el material base que realmente se gastó en el proceso.',
          'Si se deja vacío, el sistema toma los mismos kg de salida como descuento del inventario general.',
          'Si sí mides merma o diferencia real, puedes capturarlo para reflejar un consumo distinto.',
        ],
      ),
      _GuideSectionData(
        heading: 'Qué afecta Producción',
        lines: [
          'Baja el inventario general de la familia activa.',
          'Sube el inventario comercial o clasificado del material producido.',
          'Editar o eliminar una producción cambia automáticamente el inventario relacionado.',
        ],
      ),
      _GuideSectionData(
        heading: 'Ejemplos rápidos',
        lines: [
          'Cartón: entra CARTÓN, Producción genera PACA AMERICANA, baja CARTÓN y sube PACA AMERICANA.',
          'Papel: entra PAPEL, Producción genera ARCHIVO, baja PAPEL y sube ARCHIVO.',
          'Metal: entra METAL, Producción genera ALUMINIO, baja METAL y sube ALUMINIO.',
        ],
      ),
    ],
  );
}

Future<void> _inventoryLogoutFlow(BuildContext context) async {
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
  if (ok != true) return;
  if (!context.mounted) return;
  await signOutAndRouteToLogin(context);
}

Future<void> _inventoryGoToDashboardFlow(
  BuildContext context,
  SupabaseClient supa,
) async {
  final profile = await AuthAccess.resolveCurrentProfile();
  if (!AuthAccess.canAccessDashboard(profile)) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Acceso no autorizado')));
    }
    return;
  }

  if (!context.mounted) return;
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pushReplacement(
      appPageRoute(
        page: const DashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
    return;
  }
  nav.push(
    appPageRoute(
      page: const DashboardPage(instantOpen: true),
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 360),
    ),
  );
}

Future<void> _inventoryGoToGeneralDashboardFlow(BuildContext context) async {
  final profile = await AuthAccess.resolveCurrentProfile();
  if (!AuthAccess.canAccessGeneralDashboard(profile)) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Acceso no autorizado')));
    }
    return;
  }

  if (!context.mounted) return;
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pushReplacement(
      appPageRoute(
        page: const GeneralDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
    return;
  }
  nav.push(
    appPageRoute(
      page: const GeneralDashboardPage(instantOpen: true),
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 360),
    ),
  );
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage>
    with WidgetsBindingObserver {
  final SupabaseClient supa = Supabase.instance.client;

  final TextEditingController _inventoryAvgBaleWeightC = TextEditingController(
    text: '850',
  );

  bool _loading = true;
  bool _autoReloading = false;
  bool _pendingAutoReload = false;
  Timer? _autoRefreshTimer;
  Timer? _deferredAutoRefreshTimer;
  RealtimeChannel? _inventoryRealtimeChannel;
  DateTime? _lastBackgroundRefreshAt;
  String _summarySnapshotSignature = '';
  static const Duration _backgroundRefreshMinGap = Duration(seconds: 12);
  static const Duration _backgroundRefreshRetryDelay = Duration(seconds: 8);

  InventoryGridTopBarData? _inputsTopBar;
  InventoryGridTopBarData? _outputsTopBar;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAll();
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _deferredAutoRefreshTimer?.cancel();
    _inventoryRealtimeChannel?.unsubscribe();
    _inventoryAvgBaleWeightC.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestAutoReload(force: true);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _setupAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 120), (_) {
      _requestAutoReload();
    });

    _inventoryRealtimeChannel?.unsubscribe();
    _inventoryRealtimeChannel = supa
        .channel('inventory-auto-refresh')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'movements',
          callback: (_) => _requestAutoReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'production_runs',
          callback: (_) => _requestAutoReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'opening_balances',
          callback: (_) => _requestAutoReload(),
        )
        .subscribe();
  }

  String _summarySignature(
    Map<String, dynamic>? widgetRow,
    List<Map<String, dynamic>> rows,
  ) => jsonEncode({'widget_row': widgetRow, 'rows': rows});

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
    if (!force && (_autoReloading || _loading || _isEditableTextFocused())) {
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
    if (_autoReloading) {
      _queueDeferredAutoReload();
      return;
    }
    unawaited(_refreshSilentlyIfIdle(force: force));
  }

  bool _isEditableTextFocused() {
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  Future<void> _refreshSilentlyIfIdle({bool force = false}) async {
    if (!mounted || _autoReloading) return;
    _autoReloading = true;
    try {
      await _loadAll(showRefreshing: false, onlyApplyIfChanged: true);
      _lastBackgroundRefreshAt = DateTime.now();
    } finally {
      _autoReloading = false;
      if (_pendingAutoReload && mounted) {
        if (force || !_isEditableTextFocused()) {
          _pendingAutoReload = false;
          _requestAutoReload();
        } else {
          _queueDeferredAutoReload();
        }
      }
    }
  }

  Future<bool> _loadAll({
    bool showRefreshing = false,
    bool onlyApplyIfChanged = false,
  }) async {
    try {
      final widgetRow = await _loadWidgetRow();
      final inventoryRows = await supa
          .from('v_inventory_summary')
          .select()
          .order('material', ascending: true);
      final nextRows = inventoryRows.cast<Map<String, dynamic>>();
      final nextSignature = _summarySignature(widgetRow, nextRows);
      if (onlyApplyIfChanged && nextSignature == _summarySnapshotSignature) {
        if (_loading && mounted) {
          setState(() => _loading = false);
        }
        return false;
      }
      if (!mounted) return false;
      setState(() {
        _summarySnapshotSignature = nextSignature;
      });
      return true;
    } catch (e) {
      _toast('No se pudo cargar inventarios: $e');
      return false;
    } finally {
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _loadWidgetRow() async {
    final rows = await supa.from('v_cardboard_widget').select();
    if (rows.isNotEmpty) {
      return rows.first;
    }
    return null;
  }

  Future<void> _logout() async {
    await _inventoryLogoutFlow(context);
  }

  Future<void> _goToDashboard() async {
    await _inventoryGoToDashboardFlow(context, supa);
  }

  Future<void> _goToGeneralDashboard() async {
    await _inventoryGoToGeneralDashboardFlow(context);
  }

  Future<void> _goToServices() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const ServicesPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToProduction() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const InventoryProductionPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToInventory() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const InventoryStockPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToWeighings() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const WeighingsPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToMaintenance() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const MaintenancePage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToWarehouse() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const WarehousePage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: ServicesShell(
        headerTitle: 'Entradas y Salidas',
        activeOverlayModule: ServicesOverlayNavModule.entradasSalidas,
        onLogout: _logout,
        onGoToGeneralDashboard: _goToGeneralDashboard,
        onGoToOperacion: _goToDashboard,
        onGoToEntriesAndOutputs: () async {},
        onGoToInventory: _goToInventory,
        onGoToServices: _goToServices,
        onGoToProduction: _goToProduction,
        onGoToWeighings: _goToWeighings,
        onGoToMaintenance: _goToMaintenance,
        onGoToWarehouse: _goToWarehouse,
        onGoToCatalogs: null,
        topContent: Builder(
          builder: (context) {
            final tc = DefaultTabController.of(context);
            final activeData = tc.index == 0 ? _inputsTopBar : _outputsTopBar;
            if (activeData == null) return const SizedBox.shrink();
            return AnimatedBuilder(
              animation: tc.animation!,
              builder: (context, child) {
                final current = tc.index == 0 ? _inputsTopBar : _outputsTopBar;
                if (current == null) return const SizedBox.shrink();
                return InventoryGridTopBar(data: current, showMetric: false);
              },
            );
          },
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Builder(
                builder: (tabContext) {
                  final tabController = DefaultTabController.of(tabContext);
                  return AnimatedBuilder(
                    animation: tabController.animation!,
                    builder: (context, child) {
                      final currentData = tabController.index == 0
                          ? _inputsTopBar
                          : _outputsTopBar;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final tabs = Align(
                                alignment: Alignment.topLeft,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 310,
                                  ),
                                  child: const _InventoryFolderTabs(),
                                ),
                              );
                              final metric = currentData == null
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 330,
                                        ),
                                        child: InventoryGridTopBar(
                                          data: currentData,
                                          showActions: false,
                                        ),
                                      ),
                                    );

                              if (constraints.maxWidth < 760) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    tabs,
                                    if (currentData != null) ...[
                                      const SizedBox(height: 8),
                                      metric,
                                    ],
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: tabs),
                                  if (currentData != null) ...[
                                    const SizedBox(width: 8),
                                    metric,
                                  ],
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildMovementTab(flow: 'IN'),
                                _buildMovementTab(flow: 'OUT'),
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
    );
  }

  Widget _buildMovementTab({required String flow}) {
    return InventoryMovementsGrid(
      flow: flow,
      showTopBarChrome: false,
      onTopBarChanged: (data) {
        if (!mounted) return;
        setState(() {
          if (flow == 'IN') {
            _inputsTopBar = data;
          } else {
            _outputsTopBar = data;
          }
        });
      },
      onChanged: () => _loadAll(showRefreshing: true),
    );
  }
}

class _InventoryFolderTabs extends StatelessWidget {
  const _InventoryFolderTabs();

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);

    Widget tabItem({
      required int index,
      required IconData icon,
      required String label,
    }) {
      final selected = controller.index == index;
      final railFill = Colors.white.withValues(alpha: 0.22);
      final activeFill = const Color(0x55FFFFFF);

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => controller.animateTo(index),
            child: SizedBox(
              height: 64,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    margin: EdgeInsets.only(top: selected ? 0 : 12, bottom: 2),
                    decoration: BoxDecoration(
                      color: selected ? activeFill : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(13),
                        topRight: Radius.circular(13),
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      border: Border.all(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.44)
                            : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              color: const Color(0xFF0B2B2B),
                              size: 20,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                                color: Color(0xFF0B2B2B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: -1,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: railFill,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, child) {
        return SizedBox(
          height: 64,
          child: Row(
            children: [
              tabItem(
                index: 0,
                icon: Icons.download_rounded,
                label: 'Entradas',
              ),
              tabItem(
                index: 1,
                icon: Icons.local_shipping_rounded,
                label: 'Salidas',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InventoryStockTabs extends StatelessWidget {
  final TabController controller;

  const _InventoryStockTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 540,
        child: OperationalFolderTabs(
          controller: controller,
          maxWidth: 540,
          showBottomRail: false,
          items: const [
            OperationalFolderTabItem(
              label: 'Materia prima',
              icon: Icons.inventory_2_outlined,
            ),
            OperationalFolderTabItem(
              label: 'Patio',
              icon: Icons.warehouse_outlined,
            ),
            OperationalFolderTabItem(
              label: 'Aperturas',
              icon: Icons.event_note_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class InventoryProductionPage extends StatefulWidget {
  const InventoryProductionPage({super.key});

  @override
  State<InventoryProductionPage> createState() =>
      _InventoryProductionPageState();
}

class _InventoryProductionPageState extends State<InventoryProductionPage>
    with SingleTickerProviderStateMixin {
  final SupabaseClient supa = Supabase.instance.client;
  late final TabController _tabController;
  final Map<int, InventoryGridTopBarData?> _topBarDataByTab =
      <int, InventoryGridTopBarData?>{};

  InventoryGridTopBarData? get _currentTopBarData =>
      _topBarDataByTab[_tabController.index];

  void _handleTopBarChanged(int tabIndex, InventoryGridTopBarData data) {
    if (!mounted) return;
    setState(() => _topBarDataByTab[tabIndex] = data);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this)
      ..addListener(_handleTabIndexChanged);
  }

  void _handleTabIndexChanged() {
    if (!mounted || _tabController.indexIsChanging) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabIndexChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _logout() => _inventoryLogoutFlow(context);

  Future<void> _goToDashboard() => _inventoryGoToDashboardFlow(context, supa);

  Future<void> _goToGeneralDashboard() =>
      _inventoryGoToGeneralDashboardFlow(context);

  Future<void> _goToEntriesAndOutputs() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const InventoryPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToServices() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const ServicesPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToInventory() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const InventoryStockPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToWeighings() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const WeighingsPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToMaintenance() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const MaintenancePage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToWarehouse() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const WarehousePage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabSpecs = const [
      ('CARTON', 'Cartón', Icons.view_in_ar_rounded),
      ('CHATARRA', 'Chatarra', Icons.construction_rounded),
      ('METAL', 'Metal', Icons.precision_manufacturing_rounded),
      ('PLASTICO', 'Plástico', Icons.recycling_rounded),
      ('MADERA', 'Madera', Icons.forest_rounded),
      ('PAPEL', 'Papel', Icons.description_rounded),
    ];
    final topBar = _currentTopBarData;

    return ServicesShell(
      headerTitle: 'Producción',
      activeOverlayModule: ServicesOverlayNavModule.produccion,
      onLogout: _logout,
      onGoToGeneralDashboard: _goToGeneralDashboard,
      onGoToOperacion: _goToDashboard,
      onGoToEntriesAndOutputs: _goToEntriesAndOutputs,
      onGoToInventory: _goToInventory,
      onGoToServices: _goToServices,
      onGoToWeighings: _goToWeighings,
      onGoToMaintenance: _goToMaintenance,
      onGoToWarehouse: _goToWarehouse,
      onHeaderGuide: () => showProductionUsageGuideDialog(context),
      headerGuideLabel: 'Instructivo',
      onGoToCatalogs: null,
      topContent: Builder(
        builder: (context) {
          final current = _currentTopBarData;
          if (current == null) return const SizedBox.shrink();
          return InventoryGridTopBar(data: current, showMetric: false);
        },
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: AreaThemeScope(
          tokens: _kOperationsAreaTokens,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final tabs = Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 880),
                      child: _ProductionFamilyTabs(
                        controller: _tabController,
                        items: tabSpecs,
                      ),
                    ),
                  );
                  final metric = topBar == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 330),
                            child: InventoryGridTopBar(
                              data: topBar,
                              showActions: false,
                            ),
                          ),
                        );

                  if (constraints.maxWidth < 980) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        tabs,
                        if (topBar != null) ...[
                          const SizedBox(height: 8),
                          metric,
                        ],
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: tabs),
                      if (topBar != null) ...[const SizedBox(width: 8), metric],
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    InventoryTransformationGrid(
                      sourceGeneralCode: 'CARTON',
                      title: 'Cartón',
                      metricIcon: Icons.view_in_ar_rounded,
                      onTopBarChanged: (data) => _handleTopBarChanged(0, data),
                    ),
                    InventoryTransformationGrid(
                      sourceGeneralCode: 'CHATARRA',
                      title: 'Chatarra',
                      metricIcon: Icons.construction_rounded,
                      onTopBarChanged: (data) => _handleTopBarChanged(1, data),
                    ),
                    InventoryTransformationGrid(
                      sourceGeneralCode: 'METAL',
                      title: 'Metal',
                      metricIcon: Icons.precision_manufacturing_rounded,
                      onTopBarChanged: (data) => _handleTopBarChanged(2, data),
                    ),
                    InventoryTransformationGrid(
                      sourceGeneralCode: 'PLASTICO',
                      title: 'Plástico',
                      metricIcon: Icons.recycling_rounded,
                      onTopBarChanged: (data) => _handleTopBarChanged(3, data),
                    ),
                    InventoryTransformationGrid(
                      sourceGeneralCode: 'MADERA',
                      title: 'Madera',
                      metricIcon: Icons.forest_rounded,
                      onTopBarChanged: (data) => _handleTopBarChanged(4, data),
                    ),
                    InventoryTransformationGrid(
                      sourceGeneralCode: 'PAPEL',
                      title: 'Papel',
                      metricIcon: Icons.description_rounded,
                      onTopBarChanged: (data) => _handleTopBarChanged(5, data),
                    ),
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

class InventoryStockPage extends StatefulWidget {
  const InventoryStockPage({super.key});

  @override
  State<InventoryStockPage> createState() => _InventoryStockPageState();
}

class _ProductionFamilyTabs extends StatelessWidget {
  final TabController controller;
  final List<(String, String, IconData)> items;

  const _ProductionFamilyTabs({required this.controller, required this.items});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              final itemWidth = math.max(
                150.0,
                (constraints.maxWidth - 12) / 2,
              );
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (index, spec) in items.indexed)
                    SizedBox(
                      width: itemWidth,
                      child: _ProductionFamilyFolderTab(
                        icon: spec.$3,
                        label: spec.$2,
                        selected: controller.index == index,
                        onTap: () => controller.animateTo(index),
                      ),
                    ),
                ],
              );
            }

            return SizedBox(
              height: 64,
              child: Row(
                children: [
                  for (final (index, spec) in items.indexed)
                    _ProductionFamilyFolderTab(
                      icon: spec.$3,
                      label: spec.$2,
                      selected: controller.index == index,
                      expanded: true,
                      onTap: () => controller.animateTo(index),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProductionFamilyFolderTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  const _ProductionFamilyFolderTab({
    required this.icon,
    required this.label,
    required this.selected,
    this.expanded = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final railFill = Colors.white.withValues(alpha: 0.22);
    final tab = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                margin: EdgeInsets.only(top: selected ? 0 : 12, bottom: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0x55FFFFFF)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(13),
                    topRight: Radius.circular(13),
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  border: Border.all(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.44)
                        : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: const Color(0xFF0B2B2B), size: 20),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            color: Color(0xFF0B2B2B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: -1,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: railFill,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (expanded) {
      return Expanded(child: tab);
    }

    return tab;
  }
}

class _InventoryStockPageState extends State<InventoryStockPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final SupabaseClient supa = Supabase.instance.client;
  late final TabController _tabController;
  final Map<int, InventoryGridTopBarData?> _topBarDataByTab =
      <int, InventoryGridTopBarData?>{};
  final TextEditingController _inventoryAvgBaleWeightC = TextEditingController(
    text: '850',
  );
  final DateTime _today = DateUtils.dateOnly(DateTime.now());

  bool _loading = true;
  bool _autoReloading = false;
  bool _pendingAutoReload = false;
  bool _exportingCsv = false;
  Timer? _autoRefreshTimer;
  RealtimeChannel? _inventoryRealtimeChannel;

  Map<String, dynamic>? _widgetRow;
  List<Map<String, dynamic>> _inventoryRows = [];
  Map<String, dynamic>? _monthlyCutRow;
  List<Map<String, dynamic>> _openingBalanceRows = [];
  List<Map<String, dynamic>> _openingTemplateRows = [];
  List<Map<String, dynamic>> _cutSuggestedClosingRows = [];
  List<_CommercialMaterialOption> _commercialMaterials = [];
  List<_GeneralMaterialOption> _generalMaterials = [];
  Map<String, Set<String>> _commercialSourceRulesByCode = {};
  List<String> _sites = [];
  String? _selectedSite;
  late DateTime _selectedPeriodMonth;
  late DateTime _selectedAsOfDate;
  late DateTime _inventoryFromDate;
  late DateTime _inventoryToDate;
  String? _cutActionBusy;

  InventoryGridTopBarData? get _currentTopBarData =>
      _topBarDataByTab[_tabController.index];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_handleTabIndexChanged);
    _selectedPeriodMonth = DateTime(_today.year, _today.month, 1);
    _selectedAsOfDate = _today;
    _inventoryFromDate = _selectedPeriodMonth;
    _inventoryToDate = _today;
  }

  void _handleTabIndexChanged() {
    if (!mounted || _tabController.indexIsChanging) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabIndexChanged)
      ..dispose();
    _inventoryAvgBaleWeightC.dispose();
    super.dispose();
  }

  void _handleTopBarChanged(int tabIndex, InventoryGridTopBarData data) {
    if (!mounted) return;
    setState(() => _topBarDataByTab[tabIndex] = data);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestAutoReload();
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _csvEscape(dynamic value) {
    if (value == null) return '';
    final text = value.toString();
    final escaped = text.replaceAll('"', '""');
    final needsQuotes =
        escaped.contains(',') ||
        escaped.contains('\n') ||
        escaped.contains('\r') ||
        escaped.contains('"');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  Future<String?> _saveCsvToDownloads(String fileName, String content) =>
      saveCsvFile(
        fileName: fileName,
        content: content,
        dialogTitle: 'Guardar CSV de inventario',
      );

  Future<void> _exportInventoryDetailsCsv() async {
    if (_exportingCsv) return;
    setState(() => _exportingCsv = true);
    try {
      const headers = <String>[
        'material',
        'material_label',
        'opening_kg',
        'net_movement_kg',
        'prod_in_kg',
        'prod_out_kg',
        'on_hand_kg',
      ];
      final sb = StringBuffer()
        ..write('\uFEFF')
        ..writeln(headers.join(','));
      for (final row in _inventoryRows) {
        sb.writeln(
          <dynamic>[
            row['material'],
            _materialLabel(row['material']?.toString()),
            row['opening_kg'],
            row['net_movement_kg'],
            row['prod_in_kg'],
            row['prod_out_kg'],
            row['on_hand_kg'],
          ].map(_csvEscape).join(','),
        );
      }
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final path = await _saveCsvToDownloads(
        'inventario_detalles_${_dateSql(_inventoryFromDate).replaceAll('-', '')}_${_dateSql(_inventoryToDate).replaceAll('-', '')}_$stamp.csv',
        sb.toString(),
      );
      if (path != null) _toast('CSV exportado en: $path');
    } catch (e) {
      _toast('No se pudo exportar CSV: $e');
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Future<void> _exportOpeningBalancesCsv() async {
    if (_exportingCsv) return;
    setState(() => _exportingCsv = true);
    try {
      const headers = <String>[
        'period_month',
        'as_of_date',
        'site',
        'material',
        'material_label',
        'commercial_material_code',
        'weight_kg',
        'source',
        'is_manual',
        'notes',
        'locked_at',
      ];
      final sb = StringBuffer()
        ..write('\uFEFF')
        ..writeln(headers.join(','));
      for (final row in _openingBalanceRows) {
        sb.writeln(
          <dynamic>[
            row['period_month'],
            row['as_of_date'],
            row['site'],
            row['material'],
            _materialLabel(row['material']?.toString()),
            row['commercial_material_code'],
            row['weight_kg'],
            row['source'],
            row['is_manual'],
            row['notes'],
            row['locked_at'],
          ].map(_csvEscape).join(','),
        );
      }
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final path = await _saveCsvToDownloads(
        'opening_balances_${_dateSql(_selectedPeriodMonth).replaceAll('-', '')}_$stamp.csv',
        sb.toString(),
      );
      if (path != null) _toast('CSV exportado en: $path');
    } catch (e) {
      _toast('No se pudo exportar CSV: $e');
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Future<void> _logout() => _inventoryLogoutFlow(context);

  Future<void> _goToDashboard() => _inventoryGoToDashboardFlow(context, supa);

  Future<void> _goToGeneralDashboard() =>
      _inventoryGoToGeneralDashboardFlow(context);

  Future<void> _goToEntriesAndOutputs() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const InventoryPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToProduction() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const InventoryProductionPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToServices() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const ServicesPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToWeighings() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const WeighingsPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToMaintenance() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const MaintenancePage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _goToWarehouse() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const WarehousePage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _showInventoryUsageGuide() async {
    await _showModuleGuideDialog(
      context,
      title: 'Instructivo de uso',
      subtitle: 'Inventario',
      sections: const [
        _GuideSectionData(
          heading: 'Para qué sirve',
          lines: [
            'Inventario muestra las existencias actuales del sistema.',
            'Se divide en inventario general y en inventario comercial o clasificado de patio.',
          ],
        ),
        _GuideSectionData(
          heading: 'Cómo está dividido',
          lines: [
            'Inventario general muestra la materia prima o familia base: CARTÓN, CHATARRA, METAL, PAPEL, PLÁSTICO y MADERA.',
            'Inventario comercial muestra lo que ya existe clasificado en patio: PACAS, ARCHIVO, ALUMINIO, TARIMA y demás clasificados.',
            'Aperturas muestra con cuánto arrancó el sistema o el periodo.',
          ],
        ),
        _GuideSectionData(
          heading: 'Cómo se calcula',
          lines: [
            'Existencia actual = Apertura + Movimiento.',
            'Apertura es el saldo inicial con el que arrancaste.',
            'Movimiento es todo lo que pasó después: entradas, salidas, producción o ajustes.',
          ],
        ),
        _GuideSectionData(
          heading: 'Cómo leer cada nivel',
          lines: [
            'En general, una entrada suma y Producción descuenta.',
            'En comercial, Producción suma y las ventas descuentan.',
            'Por eso una paca vendida baja del patio clasificado, no del material base.',
          ],
        ),
        _GuideSectionData(
          heading: 'Aperturas, cortes y arrastre',
          lines: [
            'La apertura inicial sí es necesaria para arrancar limpio.',
            'Después el inventario puede seguir arrastrándose solo con la operación diaria, sin abrir cada mes a la fuerza.',
            'Los cortes siguen existiendo: se compara el saldo del sistema contra el conteo físico y se ajusta si hace falta.',
          ],
        ),
        _GuideSectionData(
          heading: 'Ejemplos rápidos',
          lines: [
            'Si abres CARTÓN con 1000, entra 500 y Producción consume 300, el movimiento neto es +200 y la existencia actual queda en 1200.',
            'Si PACA AMERICANA no tiene apertura, Producción suma 920 y una venta descuenta 300, el movimiento neto es +620 y esa es la existencia actual.',
            'El arrastre entre meses sale del historial de aperturas y movimientos, no de una captura manual separada llamada movimiento.',
          ],
        ),
      ],
    );
  }

  void _setupAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 120), (_) {
      _requestAutoReload();
    });

    _inventoryRealtimeChannel?.unsubscribe();
    _inventoryRealtimeChannel = supa
        .channel('inventory-stock-auto-refresh')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'movements',
          callback: (_) => _requestAutoReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'production_runs',
          callback: (_) => _requestAutoReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'opening_balances',
          callback: (_) => _requestAutoReload(),
        )
        .subscribe();
  }

  void _requestAutoReload() {
    if (!mounted) return;
    if (_autoReloading || _loading || _isEditableTextFocused()) {
      _pendingAutoReload = true;
      return;
    }
    unawaited(_refreshSilentlyIfIdle());
  }

  bool _isEditableTextFocused() {
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  Future<void> _refreshSilentlyIfIdle() async {
    if (!mounted || _autoReloading) return;
    _autoReloading = true;
    try {
      await _loadAll(showRefreshing: false);
    } finally {
      _autoReloading = false;
      if (_pendingAutoReload && mounted) {
        _pendingAutoReload = false;
        _requestAutoReload();
      }
    }
  }

  Future<void> _loadAll({bool showRefreshing = false}) async {
    if (!showRefreshing && mounted) {
      setState(() => _loading = true);
    }

    try {
      await _ensureSitesLoaded();
      final site = _selectedSite;
      if (site == null || site.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _widgetRow = null;
          _inventoryRows = const [];
          _monthlyCutRow = null;
          _openingBalanceRows = const [];
          _cutSuggestedClosingRows = const [];
        });
        return;
      }
      final prevMonthEnd = DateTime(
        _selectedPeriodMonth.year,
        _selectedPeriodMonth.month,
        1,
      ).subtract(const Duration(days: 1));
      final prevMonthStart = DateTime(prevMonthEnd.year, prevMonthEnd.month, 1);
      final results = await Future.wait<dynamic>([
        supa.rpc(
          'rpc_inventory_summary_by_period',
          params: {
            'p_period_month': _dateSql(
              DateTime(_inventoryFromDate.year, _inventoryFromDate.month, 1),
            ),
            'p_as_of_date': _dateSql(_inventoryToDate),
            'p_site': site,
          },
        ),
        supa
            .from('inventory_monthly_cuts')
            .select('period_month,status,generated_at,locked_at,notes')
            .eq('period_month', _dateSql(_selectedPeriodMonth))
            .maybeSingle(),
        supa
            .from('opening_balances')
            .select(
              'id,period_month,as_of_date,material,commercial_material_code,weight_kg,site,source,is_manual,notes,locked_at',
            )
            .eq('period_month', _dateSql(_selectedPeriodMonth))
            .eq('site', site)
            .order('material', ascending: true)
            .order('commercial_material_code', ascending: true),
        supa
            .from('commercial_material_catalog')
            .select('code,name,inventory_material,material_id,active')
            .eq('active', true)
            .order('name'),
        supa
            .from('commercial_material_source_rules')
            .select('commercial_material_code,allowed_source_material')
            .eq('is_active', true),
        supa
            .from('inventory_opening_templates')
            .select(
              'id,site,material,commercial_material_code,sort_order,is_active',
            )
            .inFilter('site', <String>[site, 'DICSA'])
            .eq('is_active', true)
            .order('site')
            .order('sort_order')
            .order('commercial_material_code'),
        supa
            .from('materials')
            .select('id,name,inventory_material_code')
            .order('name'),
        supa.rpc(
          'rpc_inventory_summary_by_period',
          params: {
            'p_period_month': _dateSql(prevMonthStart),
            'p_as_of_date': _dateSql(prevMonthEnd),
            'p_site': site,
          },
        ),
      ]);
      final rows = _withOperationalMaterials(
        (results[0] as List).cast<Map<String, dynamic>>(),
      );
      final widgetRow = _buildWidgetRowFromInventoryRows(rows);
      final cutSuggestedClosingRows = _withOperationalMaterials(
        (results[7] as List).cast<Map<String, dynamic>>(),
      );
      final commercialMaterials =
          (results[3] as List)
              .cast<Map<String, dynamic>>()
              .map(
                (r) => _CommercialMaterialOption(
                  code: (r['code'] ?? '').toString(),
                  name: (r['name'] ?? '').toString(),
                  inventoryMaterial: r['inventory_material']?.toString(),
                  materialId: r['material_id']?.toString(),
                ),
              )
              .where((e) => e.code.isNotEmpty && e.name.isNotEmpty)
              .toList()
            ..sort((a, b) {
              final byName = _normalizeSortKey(
                a.name,
              ).compareTo(_normalizeSortKey(b.name));
              if (byName != 0) return byName;
              return a.code.compareTo(b.code);
            });
      final generalMaterials =
          (results[6] as List)
              .cast<Map<String, dynamic>>()
              .map(
                (r) => _GeneralMaterialOption(
                  id: (r['id'] ?? '').toString(),
                  name: (r['name'] ?? '').toString(),
                  inventoryMaterialCode: r['inventory_material_code']
                      ?.toString(),
                ),
              )
              .where((e) => e.id.isNotEmpty && e.name.isNotEmpty)
              .toList()
            ..sort((a, b) {
              final byName = _normalizeSortKey(
                a.name,
              ).compareTo(_normalizeSortKey(b.name));
              if (byName != 0) return byName;
              return a.id.compareTo(b.id);
            });
      final commercialSourceRulesByCode = <String, Set<String>>{};
      for (final row in (results[4] as List).cast<Map<String, dynamic>>()) {
        final code = _normalizeInventoryMaterialKey(
          (row['commercial_material_code'] ?? '').toString(),
        );
        final source = _normalizeInventoryMaterialKey(
          (row['allowed_source_material'] ?? '').toString(),
        );
        if (code.isEmpty || source.isEmpty) continue;
        commercialSourceRulesByCode
            .putIfAbsent(code, () => <String>{})
            .add(source);
      }
      if (!mounted) return;
      setState(() {
        _widgetRow = widgetRow;
        _inventoryRows = rows;
        _monthlyCutRow = _normalizeMonthlyCutRow(
          results[1] as Map<String, dynamic>?,
        );
        _openingBalanceRows = (results[2] as List).cast<Map<String, dynamic>>();
        _openingTemplateRows = (results[5] as List)
            .cast<Map<String, dynamic>>();
        _cutSuggestedClosingRows = cutSuggestedClosingRows;
        _commercialMaterials = commercialMaterials;
        _generalMaterials = generalMaterials;
        _commercialSourceRulesByCode = commercialSourceRulesByCode;
      });
    } catch (e) {
      _toast('No se pudo cargar inventarios: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _ensureSitesLoaded() async {
    if (_sites.isNotEmpty && _selectedSite != null) return;
    final results = await Future.wait<dynamic>([
      supa.from('opening_balances').select('site').order('site'),
      supa.from('movements').select('site').order('site'),
    ]);
    final set = <String>{};
    for (final result in results) {
      for (final row in (result as List).cast<Map<String, dynamic>>()) {
        final site = (row['site'] ?? '').toString().trim();
        if (site.isNotEmpty) set.add(site);
      }
    }
    final sites = set.toList()
      ..sort((a, b) => a.toUpperCase().compareTo(b.toUpperCase()));
    if (!sites.contains(_kFixedInventorySite)) {
      sites.insert(0, _kFixedInventorySite);
    }
    if (!mounted) return;
    setState(() {
      _sites = sites;
      _selectedSite = _kFixedInventorySite;
    });
  }

  Map<String, dynamic> _buildWidgetRowFromInventoryRows(
    List<Map<String, dynamic>> rows,
  ) {
    double bulkKg = 0;
    double balesKg = 0;
    double scrapKg = 0;
    double metalKg = 0;
    double woodKg = 0;
    double paperKg = 0;
    double plasticKg = 0;
    for (final row in rows) {
      final material = _normalizeOperationalSummaryMaterial(
        (row['material'] ?? '').toString(),
      );
      final onHand = _num(row['on_hand_kg']) ?? 0;
      switch (material) {
        case 'CARDBOARD_BULK_NATIONAL':
        case 'CARDBOARD_BULK_AMERICAN':
          bulkKg += onHand;
          break;
        case 'BALE_NATIONAL':
        case 'BALE_AMERICAN':
        case 'BALE_CLEAN':
        case 'BALE_TRASH':
          balesKg += onHand;
          break;
        case 'SCRAP':
          scrapKg += onHand;
          break;
        case 'METAL':
        case 'METAL_ALUMINUM':
        case 'METAL_STEEL':
        case 'METAL_COPPER':
        case 'METAL_BRASS':
        case 'METAL_OTHER':
          metalKg += onHand;
          break;
        case 'WOOD':
          woodKg += onHand;
          break;
        case 'PAPER':
          paperKg += onHand;
          break;
        case 'PLASTIC':
          plasticKg += onHand;
          break;
      }
    }
    return <String, dynamic>{
      'bulk_kg': bulkKg,
      'bales_kg': balesKg,
      'cardboard_kg': bulkKg + balesKg,
      'scrap_kg': scrapKg,
      'metal_kg': metalKg,
      'wood_kg': woodKg,
      'paper_kg': paperKg,
      'plastic_kg': plasticKg,
    };
  }

  List<Map<String, dynamic>> _withOperationalMaterials(
    List<Map<String, dynamic>> rows,
  ) {
    final metalRows = rows
        .where(
          (r) => _isMetalOperationalMaterial((r['material'] ?? '').toString()),
        )
        .toList();
    final paperRows = rows
        .where(
          (r) => _isPaperOperationalMaterial((r['material'] ?? '').toString()),
        )
        .toList();
    final metalAggregate = metalRows.isEmpty
        ? null
        : <String, dynamic>{
            'material': 'METAL',
            'opening_kg': metalRows.fold<double>(
              0,
              (sum, r) => sum + (_num(r['opening_kg']) ?? 0),
            ),
            'net_movement_kg': metalRows.fold<double>(
              0,
              (sum, r) => sum + (_num(r['net_movement_kg']) ?? 0),
            ),
            'prod_in_kg': metalRows.fold<double>(
              0,
              (sum, r) => sum + (_num(r['prod_in_kg']) ?? 0),
            ),
            'prod_out_kg': metalRows.fold<double>(
              0,
              (sum, r) => sum + (_num(r['prod_out_kg']) ?? 0),
            ),
            'on_hand_kg': metalRows.fold<double>(
              0,
              (sum, r) => sum + (_num(r['on_hand_kg']) ?? 0),
            ),
          };
    final paperAggregate = paperRows.isEmpty
        ? null
        : <String, dynamic>{
            'material': 'PAPER',
            'opening_kg': paperRows.fold<double>(
              0,
              (sum, r) => sum + (_num(r['opening_kg']) ?? 0),
            ),
            'net_movement_kg': paperRows.fold<double>(
              0,
              (sum, r) => sum + (_num(r['net_movement_kg']) ?? 0),
            ),
            'prod_in_kg': paperRows.fold<double>(
              0,
              (sum, r) => sum + (_num(r['prod_in_kg']) ?? 0),
            ),
            'prod_out_kg': paperRows.fold<double>(
              0,
              (sum, r) => sum + (_num(r['prod_out_kg']) ?? 0),
            ),
            'on_hand_kg': paperRows.fold<double>(
              0,
              (sum, r) => sum + (_num(r['on_hand_kg']) ?? 0),
            ),
          };
    final byMaterial = <String, Map<String, dynamic>>{
      for (final row in rows)
        if ((row['material'] ?? '').toString().isNotEmpty &&
            !_isMetalOperationalMaterial((row['material'] ?? '').toString()) &&
            !_isPaperOperationalMaterial((row['material'] ?? '').toString()))
          _normalizeOperationalSummaryMaterial(
            (row['material'] as Object).toString(),
          ): row,
    };
    if (metalAggregate != null) {
      byMaterial['METAL'] = metalAggregate;
    }
    if (paperAggregate != null) {
      byMaterial['PAPER'] = paperAggregate;
    }
    final out = <Map<String, dynamic>>[];
    for (final material in _kInventorySummaryMaterials.map((m) => m.value)) {
      out.add(
        byMaterial[material] ??
            <String, dynamic>{
              'material': material,
              'opening_kg': 0,
              'net_movement_kg': 0,
              'prod_in_kg': 0,
              'prod_out_kg': 0,
              'on_hand_kg': 0,
            },
      );
    }
    for (final row in rows) {
      final material = _normalizeOperationalSummaryMaterial(
        (row['material'] ?? '').toString(),
      );
      if (_isMetalOperationalMaterial(material)) continue;
      if (_isPaperOperationalMaterial(material)) continue;
      if (!_kInventorySummaryMaterials.any((m) => m.value == material)) {
        out.add(<String, dynamic>{...row, 'material': material});
      }
    }
    return out;
  }

  String _normalizeOperationalSummaryMaterial(String material) {
    switch (material.trim().toUpperCase()) {
      case 'PAPEL_REVUELTO':
      case 'REVUELTO':
        return 'PAPER';
      default:
        return material;
    }
  }

  bool _isMetalOperationalMaterial(String material) {
    switch (material) {
      case 'METAL':
      case 'METAL_ALUMINUM':
      case 'METAL_STEEL':
      case 'METAL_COPPER':
      case 'METAL_BRASS':
      case 'METAL_OTHER':
        return true;
      default:
        return false;
    }
  }

  bool _isPaperOperationalMaterial(String material) {
    switch (material.trim().toUpperCase()) {
      case 'PAPER':
      case 'PAPEL_REVUELTO':
      case 'REVUELTO':
        return true;
      default:
        return false;
    }
  }

  List<_CommercialMaterialOption> _commercialOptionsForMaterial(
    String material,
  ) {
    final filtered = _commercialMaterials
        .where(
          (c) => _commercialMatchesInventoryMaterial(
            option: c,
            selectedMaterial: material,
            generalMaterials: _generalMaterials,
            commercialSourceRulesByCode: _commercialSourceRulesByCode,
          ),
        )
        .toList();
    filtered.sort((a, b) {
      final byName = _normalizeSortKey(
        a.name,
      ).compareTo(_normalizeSortKey(b.name));
      if (byName != 0) return byName;
      return a.code.compareTo(b.code);
    });
    return filtered;
  }

  bool _openingBalanceDuplicateExists({
    required String material,
    required String? commercialMaterialCode,
    String? excludingId,
  }) {
    final normalizedCommercial = (commercialMaterialCode ?? '').trim();
    for (final row in _openingBalanceRows) {
      final rowId = row['id']?.toString();
      if (excludingId != null && rowId == excludingId) continue;
      final rowMaterial = (row['material'] ?? '').toString();
      final rowCommercial = (row['commercial_material_code'] ?? '')
          .toString()
          .trim();
      if (rowMaterial == material && rowCommercial == normalizedCommercial) {
        return true;
      }
    }
    return false;
  }

  Future<void> _ensureMonthlyCutExists() async {
    if (_monthlyCutRow != null) return;

    final periodMonth = _dateSql(_selectedPeriodMonth);
    final existing = await supa
        .from('inventory_monthly_cuts')
        .select('period_month,status,generated_at,locked_at,notes')
        .eq('period_month', periodMonth)
        .maybeSingle();
    if (existing != null) {
      final normalized = _normalizeMonthlyCutRow(existing);
      if (!mounted) return;
      setState(() => _monthlyCutRow = normalized);
      return;
    }

    final statusCandidates = <String>['abierto', 'draft', 'open'];
    PostgrestException? lastStatusError;

    for (final status in statusCandidates) {
      try {
        await supa.from('inventory_monthly_cuts').insert({
          'period_month': periodMonth,
          'month': _selectedPeriodMonth.month,
          'year': _selectedPeriodMonth.year,
          'status': status,
        });
        if (!mounted) return;
        setState(() {
          _monthlyCutRow = _normalizeMonthlyCutRow({
            'period_month': periodMonth,
            'status': status,
            'generated_at': null,
            'locked_at': null,
            'notes': null,
          });
        });
        return;
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          final fetched = await supa
              .from('inventory_monthly_cuts')
              .select('period_month,status,generated_at,locked_at,notes')
              .eq('period_month', periodMonth)
              .maybeSingle();
          if (fetched != null) {
            final normalized = _normalizeMonthlyCutRow(fetched);
            if (!mounted) return;
            setState(() => _monthlyCutRow = normalized);
            return;
          }
        }
        if (e.code == '23514' ||
            e.message.contains('inventory_monthly_cuts_status_check')) {
          lastStatusError = e;
          continue;
        }
        rethrow;
      }
    }

    if (lastStatusError != null) {
      throw lastStatusError;
    }
  }

  Future<void> _setPeriodMonth(DateTime nextPeriod) async {
    final normalized = DateTime(nextPeriod.year, nextPeriod.month, 1);
    final nextAsOf = _selectedAsOfDate.isBefore(normalized)
        ? normalized
        : _selectedAsOfDate;
    setState(() {
      _selectedPeriodMonth = normalized;
      _selectedAsOfDate = DateUtils.dateOnly(nextAsOf);
    });
    await _loadAll(showRefreshing: true);
  }

  Future<void> _pickInventoryDateRange() async {
    final picked = await _showInventoryDateRangeFilterDialog(
      context,
      label: 'FECHA',
      bounds: DateTimeRange(
        start: DateTime(2020, 1, 1),
        end: DateTime(_today.year + 2, 12, 31),
      ),
      initialRange: DateTimeRange(
        start: _inventoryFromDate,
        end: _inventoryToDate.isBefore(_inventoryFromDate)
            ? _inventoryFromDate
            : _inventoryToDate,
      ),
    );
    if (picked == null || !mounted) return;
    if (picked.clear) {
      setState(() {
        _inventoryFromDate = DateTime(_today.year, _today.month, 1);
        _inventoryToDate = _today;
      });
      await _loadAll(showRefreshing: true);
      return;
    }
    if (picked.range == null) return;
    setState(() {
      _inventoryFromDate = DateUtils.dateOnly(picked.range!.start);
      _inventoryToDate = DateUtils.dateOnly(picked.range!.end);
    });
    await _loadAll(showRefreshing: true);
  }

  Future<void> _runCutAction(
    String action,
    Future<dynamic> Function() runner,
  ) async {
    if (_cutActionBusy != null) return;
    setState(() => _cutActionBusy = action);
    try {
      await runner();
      if (!mounted) return;
      await _loadAll(showRefreshing: true);
      switch (action) {
        case 'generate':
          _toast('Corte mensual generado');
          break;
        case 'regenerate':
          _toast('Corte mensual regenerado');
          break;
        case 'lock':
          _toast('Corte mensual bloqueado');
          break;
        case 'unlock':
          _toast('Corte mensual desbloqueado');
          break;
      }
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('No se pudo ejecutar la acción: $e');
    } finally {
      if (mounted) setState(() => _cutActionBusy = null);
    }
  }

  Future<void> _generateCut({required bool overwrite}) async {
    final site = _selectedSite;
    if (site == null || site.trim().isEmpty) {
      _toast('Selecciona un sitio');
      return;
    }
    await _runCutAction(
      overwrite ? 'regenerate' : 'generate',
      () => supa.rpc(
        'rpc_generate_inventory_monthly_cut',
        params: {
          'p_period_month': _dateSql(_selectedPeriodMonth),
          'p_overwrite_existing': overwrite,
          'p_site': site,
        },
      ),
    );
  }

  Future<void> _lockCut() async {
    await _runCutAction(
      'lock',
      () => supa.rpc(
        'rpc_lock_inventory_monthly_cut',
        params: {'p_period_month': _dateSql(_selectedPeriodMonth)},
      ),
    );
  }

  Future<void> _unlockCut() async {
    await _runCutAction(
      'unlock',
      () => supa.rpc(
        'rpc_unlock_inventory_monthly_cut',
        params: {'p_period_month': _dateSql(_selectedPeriodMonth)},
      ),
    );
  }

  Future<void> _editOpeningBalanceRow(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return;
    if (_isMonthlyCutLockedStatus(_monthlyCutRow?['status']?.toString())) {
      _toast('El corte está bloqueado. Desbloquéalo para editar.');
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => _OpeningBalanceEditDialog(
        row: row,
        materialLabel: _materialLabel(row['material']?.toString()),
        commercialOptions: _commercialOptionsForMaterial(
          (row['material'] ?? '').toString(),
        ),
      ),
    );
    if (result == null) return;

    await _saveOpeningBalanceRowEdits(row, result);
  }

  Future<void> _saveOpeningBalanceRowEdits(
    Map<String, dynamic> row,
    Map<String, dynamic> edits,
  ) async {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return;
    if (_isMonthlyCutLockedStatus(_monthlyCutRow?['status']?.toString())) {
      _toast('El corte está bloqueado. Desbloquéalo para editar.');
      return;
    }

    final nextWeight = _num(edits['weight_kg']);
    final material = (row['material'] ?? '').toString();
    final nextCommercial = edits['commercial_material_code']?.toString();
    if (nextWeight == null || nextWeight < 0) {
      _toast('Captura un opening kg válido (>= 0)');
      return;
    }
    if (_openingBalanceDuplicateExists(
      material: material,
      commercialMaterialCode: nextCommercial,
      excludingId: id,
    )) {
      _toast('Ya existe un renglón con ese material y material comercial');
      return;
    }

    try {
      await supa
          .from('opening_balances')
          .update({
            'weight_kg': nextWeight,
            'commercial_material_code': nextCommercial,
            'notes': edits.containsKey('notes') ? edits['notes'] : row['notes'],
            'is_manual': true,
            'source': 'manual',
            'locked_at': null,
          })
          .eq('id', id);
      _toast('Opening balance actualizado');
      await _loadAll(showRefreshing: true);
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('No se pudo actualizar opening balance: $e');
    }
  }

  Future<void> _addOpeningBalanceRow() async {
    final site = _selectedSite;
    if (site == null || site.trim().isEmpty) {
      _toast('Selecciona un sitio');
      return;
    }
    if (_isMonthlyCutLockedStatus(_monthlyCutRow?['status']?.toString())) {
      _toast('El corte está bloqueado. Desbloquéalo para agregar renglones.');
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => _OpeningBalanceCreateDialog(
        allCommercialMaterials: _commercialMaterials,
        generalMaterials: _generalMaterials,
        commercialSourceRulesByCode: _commercialSourceRulesByCode,
        openingTemplateRows: _openingTemplateRows,
      ),
    );
    if (result == null) return;

    final material = (result['material'] ?? '').toString();
    final commercialMaterialCode = result['commercial_material_code']
        ?.toString();
    final weight = _num(result['weight_kg']);
    if (material.isEmpty || weight == null || weight < 0) {
      _toast('Captura material y opening kg válido (>= 0)');
      return;
    }
    if (_openingBalanceDuplicateExists(
      material: material,
      commercialMaterialCode: commercialMaterialCode,
    )) {
      _toast('Ya existe un renglón con ese material y material comercial');
      return;
    }

    try {
      await _ensureMonthlyCutExists();
      await supa.from('opening_balances').insert({
        'period_month': _dateSql(_selectedPeriodMonth),
        'as_of_date': _dateSql(_selectedPeriodMonth),
        'site': site,
        'material': material,
        'commercial_material_code': commercialMaterialCode,
        'weight_kg': weight,
        'is_manual': true,
        'source': 'manual',
        'notes': result['notes'],
      });
      _toast('Opening balance agregado');
      await _loadAll(showRefreshing: true);
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('No se pudo agregar opening balance: $e');
    }
  }

  Future<void> _addOpeningBalanceRowInline(Map<String, dynamic> result) async {
    final site = _selectedSite;
    if (site == null || site.trim().isEmpty) {
      _toast('Selecciona un sitio');
      return;
    }
    if (_isMonthlyCutLockedStatus(_monthlyCutRow?['status']?.toString())) {
      _toast('El corte está bloqueado. Desbloquéalo para agregar renglones.');
      return;
    }

    final material = (result['material'] ?? '').toString();
    final commercialMaterialCode = result['commercial_material_code']
        ?.toString();
    final weight = _num(result['weight_kg']);
    if (material.isEmpty || weight == null || weight < 0) {
      _toast('Captura material y opening kg válido (>= 0)');
      return;
    }
    if (_openingBalanceDuplicateExists(
      material: material,
      commercialMaterialCode: commercialMaterialCode,
    )) {
      _toast('Ya existe un renglón con ese material y material comercial');
      return;
    }

    try {
      await _ensureMonthlyCutExists();
      await supa.from('opening_balances').insert({
        'period_month': _dateSql(_selectedPeriodMonth),
        'as_of_date': _dateSql(_selectedPeriodMonth),
        'site': site,
        'material': material,
        'commercial_material_code': commercialMaterialCode,
        'weight_kg': weight,
        'is_manual': true,
        'source': 'manual',
        'notes': result['notes'],
      });
      _toast('Opening balance agregado');
      await _loadAll(showRefreshing: true);
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('No se pudo agregar opening balance: $e');
    }
  }

  Future<void> _deleteOpeningBalanceRow(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return;
    if (_isMonthlyCutLockedStatus(_monthlyCutRow?['status']?.toString())) {
      _toast('El corte está bloqueado. Desbloquéalo para eliminar.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContractConfirmDialogKeyHandler(
        onCancel: () => Navigator.pop(dialogContext, false),
        onConfirm: () => Navigator.pop(dialogContext, true),
        child: AlertDialog(
          title: const Text('Eliminar opening balance'),
          content: Text(
            '¿Eliminar "${_materialLabel(row["material"]?.toString())}"'
            '${((row["commercial_material_code"] ?? "").toString().isNotEmpty) ? ' (${row["commercial_material_code"]})' : ''}?',
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

    try {
      await supa.from('opening_balances').delete().eq('id', id);
      _toast('Opening balance eliminado');
      await _loadAll(showRefreshing: true);
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('No se pudo eliminar opening balance: $e');
    }
  }

  Future<void> _bulkDeleteOpeningBalanceRows(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;
    if (_isMonthlyCutLockedStatus(_monthlyCutRow?['status']?.toString())) {
      _toast('El corte está bloqueado. Desbloquéalo para eliminar.');
      return;
    }
    final ids = rows
        .map((r) => (r['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContractConfirmDialogKeyHandler(
        onCancel: () => Navigator.pop(dialogContext, false),
        onConfirm: () => Navigator.pop(dialogContext, true),
        child: AlertDialog(
          title: const Text('Eliminar selección'),
          content: Text('¿Eliminar ${ids.length} renglones de apertura?'),
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
      await supa.from('opening_balances').delete().inFilter('id', ids);
      _toast('${ids.length} renglones eliminados');
      await _loadAll(showRefreshing: true);
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('No se pudo eliminar la selección: $e');
    }
  }

  Future<void> _bulkEditOpeningBalanceRows(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;
    if (_isMonthlyCutLockedStatus(_monthlyCutRow?['status']?.toString())) {
      _toast('El corte está bloqueado. Desbloquéalo para editar.');
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => _OpeningBalanceBulkEditDialog(
        rowCount: rows.length,
        allCommercialMaterials: _commercialMaterials,
      ),
    );
    if (result == null) return;

    final commercialMode = (result['commercial_mode'] ?? 'keep').toString();
    final notesMode = (result['notes_mode'] ?? 'keep').toString();
    final commercialCode = result['commercial_material_code']?.toString();
    final notes = result['notes']?.toString();

    if (commercialMode == 'keep' && notesMode == 'keep') {
      _toast('No se aplicaron cambios');
      return;
    }

    final selectedIds = rows
        .map((r) => (r['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (selectedIds.isEmpty) return;

    String finalCommercialForRow(Map<String, dynamic> row) {
      final current = (row['commercial_material_code'] ?? '').toString().trim();
      switch (commercialMode) {
        case 'set':
          return (commercialCode ?? '').trim();
        case 'clear':
          return '';
        default:
          return current;
      }
    }

    // Validate duplicates after applying the batch change.
    final seen = <String, String>{};
    for (final row in _openingBalanceRows) {
      final id = (row['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final material = (row['material'] ?? '').toString();
      final finalCommercial = selectedIds.contains(id)
          ? finalCommercialForRow(row)
          : (row['commercial_material_code'] ?? '').toString().trim();
      final key = '$material|$finalCommercial';
      final previousId = seen[key];
      if (previousId != null && previousId != id) {
        _toast(
          'La edición múltiple generaría duplicados en material/comercial. Ajusta la selección.',
        );
        return;
      }
      seen[key] = id;
    }

    final updateMap = <String, dynamic>{
      'is_manual': true,
      'source': 'manual',
      'locked_at': null,
    };
    switch (commercialMode) {
      case 'set':
        updateMap['commercial_material_code'] =
            (commercialCode ?? '').trim().isEmpty
            ? null
            : commercialCode!.trim();
        break;
      case 'clear':
        updateMap['commercial_material_code'] = null;
        break;
    }
    switch (notesMode) {
      case 'set':
        updateMap['notes'] = (notes ?? '').trim().isEmpty
            ? null
            : notes!.trim();
        break;
      case 'clear':
        updateMap['notes'] = null;
        break;
    }

    try {
      await supa
          .from('opening_balances')
          .update(updateMap)
          .inFilter('id', selectedIds.toList());
      _toast('Edición múltiple aplicada (${selectedIds.length})');
      await _loadAll(showRefreshing: true);
    } on PostgrestException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('No se pudo aplicar edición múltiple: $e');
    }
  }

  Widget _buildStockTopToolbar(TabController controller) {
    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, child) {
        final inventoryTab = controller.index == 0;
        final rowCount = inventoryTab
            ? _inventoryRows.length
            : _openingBalanceRows.length;
        final title = inventoryTab ? 'Detalles' : 'Opening balances';
        return OperationalGlassToolbarPanel(
          child: Row(
            children: [
              OutlinedButton.icon(
                style: _inventoryActionOutlinedButtonStyle(),
                onPressed: _exportingCsv
                    ? null
                    : (inventoryTab
                          ? _exportInventoryDetailsCsv
                          : _exportOpeningBalancesCsv),
                icon: _exportingCsv
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text('Descargar CSV'),
              ),
              const Spacer(),
              Text(
                '$title: $rowCount renglones',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kOperationalMetricMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topBar = _currentTopBarData;
    return DefaultTabController(
      length: 3,
      child: ServicesShell(
        headerTitle: 'Inventario',
        activeOverlayModule: ServicesOverlayNavModule.inventario,
        onLogout: _logout,
        onGoToGeneralDashboard: _goToGeneralDashboard,
        onGoToOperacion: _goToDashboard,
        onGoToEntriesAndOutputs: _goToEntriesAndOutputs,
        onGoToProduction: _goToProduction,
        onGoToInventory: () async {},
        onGoToServices: _goToServices,
        onGoToWeighings: _goToWeighings,
        onGoToMaintenance: _goToMaintenance,
        onGoToWarehouse: _goToWarehouse,
        onHeaderGuide: _showInventoryUsageGuide,
        headerGuideLabel: 'Instructivo',
        onGoToCatalogs: null,
        topContent: Builder(
          builder: (context) {
            final current = _currentTopBarData;
            if (current == null) return const SizedBox.shrink();
            return InventoryGridTopBar(data: current, showMetric: false);
          },
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: AreaThemeScope(
            tokens: _kOperationsAreaTokens,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tabs = Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: _InventoryStockTabs(controller: _tabController),
                      ),
                    );
                    final metric = topBar == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 330),
                              child: InventoryGridTopBar(
                                data: topBar,
                                showActions: false,
                              ),
                            ),
                          );

                    if (constraints.maxWidth < 980) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          tabs,
                          if (topBar != null) ...[
                            const SizedBox(height: 8),
                            metric,
                          ],
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: tabs),
                        if (topBar != null) ...[
                          const SizedBox(width: 8),
                          metric,
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: InventoryStockV2Body(
                    controller: _tabController,
                    onTopBarChanged: _handleTopBarChanged,
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

class _InventorySummaryBody extends StatelessWidget {
  final Map<String, dynamic>? widgetRow;
  final List<Map<String, dynamic>> inventoryRows;
  final List<String> sites;
  final String? selectedSite;
  final DateTime periodMonth;
  final DateTime asOfDate;
  final ValueChanged<String?> onSiteChanged;
  final VoidCallback onPickPeriodMonth;
  final VoidCallback onPickAsOfDate;
  final TextEditingController avgBaleWeightController;
  final VoidCallback onAvgChanged;

  const _InventorySummaryBody({
    required this.widgetRow,
    required this.inventoryRows,
    required this.sites,
    required this.selectedSite,
    required this.periodMonth,
    required this.asOfDate,
    required this.onSiteChanged,
    required this.onPickPeriodMonth,
    required this.onPickAsOfDate,
    required this.avgBaleWeightController,
    required this.onAvgChanged,
  });

  @override
  Widget build(BuildContext context) {
    final avgBaleWeight = _parseDouble(avgBaleWeightController.text) ?? 850;
    final bulkKg = _pickNum(widgetRow, const [
      'total_bulk_kg',
      'bulk_kg',
      'total_granel_kg',
      'granel_kg',
    ]);
    final balesKg = _pickNum(widgetRow, const [
      'total_bales_kg',
      'bales_kg',
      'total_pacas_kg',
      'pacas_kg',
    ]);
    final cardboardKg = _pickNum(widgetRow, const [
      'total_cardboard_kg',
      'cardboard_kg',
      'total_carton_kg',
      'carton_kg',
    ]);
    final scrapKg = _pickNum(widgetRow, const ['total_scrap_kg', 'scrap_kg']);
    final metalKg = _pickNum(widgetRow, const ['total_metal_kg', 'metal_kg']);
    final woodKg = _pickNum(widgetRow, const ['total_wood_kg', 'wood_kg']);
    final paperKg = _pickNum(widgetRow, const ['total_paper_kg', 'paper_kg']);
    final plasticKg = _pickNum(widgetRow, const [
      'total_plastic_kg',
      'plastic_kg',
    ]);
    final estimatedBales = avgBaleWeight > 0 ? (balesKg / avgBaleWeight) : 0;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _SectionCard(
          title: '',
          subtitle: '',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _DateRangeField(
                    from: periodMonth,
                    to: asOfDate,
                    width: 250,
                    onTap: onPickPeriodMonth,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricCard(
                    label: 'Granel total',
                    value: _formatKg(bulkKg),
                    icon: Icons.grain_rounded,
                  ),
                  _MetricCard(
                    label: 'Pacas total',
                    value: _formatKg(balesKg),
                    icon: Icons.inventory_2_rounded,
                  ),
                  _MetricCard(
                    label: 'Cartón total',
                    value: _formatKg(cardboardKg),
                    icon: Icons.scale_rounded,
                  ),
                  _MetricCard(
                    label: 'Chatarra',
                    value: _formatKg(scrapKg),
                    icon: Icons.auto_delete_rounded,
                  ),
                  _MetricCard(
                    label: 'Metal',
                    value: _formatKg(metalKg),
                    icon: Icons.hardware_rounded,
                  ),
                  _MetricCard(
                    label: 'Madera',
                    value: _formatKg(woodKg),
                    icon: Icons.forest_rounded,
                  ),
                  _MetricCard(
                    label: 'Papel',
                    value: _formatKg(paperKg),
                    icon: Icons.description_rounded,
                  ),
                  _MetricCard(
                    label: 'Plástico',
                    value: _formatKg(plasticKg),
                    icon: Icons.recycling_rounded,
                  ),
                  _MetricCard(
                    label: 'Pacas estimadas',
                    value: estimatedBales.toStringAsFixed(1),
                    caption:
                        'Asume ${avgBaleWeight.toStringAsFixed(0)} kg/paca',
                    icon: Icons.calculate_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _TextFieldBox(
                    label: 'Promedio para estimar pacas',
                    controller: avgBaleWeightController,
                    hint: '850',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    width: 260,
                    onChanged: (_) => onAvgChanged(),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Detalles',
          subtitle: '',
          child: _InventorySummaryTable(rows: inventoryRows),
        ),
      ],
    );
  }
}

class _InventoryMonthlyCutBody extends StatelessWidget {
  final List<String> sites;
  final String? selectedSite;
  final DateTime periodMonth;
  final Map<String, dynamic>? cutRow;
  final List<Map<String, dynamic>> openingBalanceRows;
  final List<Map<String, dynamic>> openingTemplateRows;
  final List<Map<String, dynamic>> suggestedClosingRows;
  final List<_CommercialMaterialOption> commercialMaterials;
  final List<_GeneralMaterialOption> generalMaterials;
  final Map<String, Set<String>> commercialSourceRulesByCode;
  final List<Map<String, dynamic>> Function() getOpeningBalanceRows;
  final String? actionBusy;
  final ValueChanged<String?> onSiteChanged;
  final ValueChanged<DateTime> onPeriodMonthChanged;
  final VoidCallback onGenerate;
  final VoidCallback onRegenerate;
  final VoidCallback onLock;
  final VoidCallback onUnlock;
  final Future<void> Function(Map<String, dynamic> row) onEditOpeningRow;
  final Future<void> Function(
    Map<String, dynamic> row,
    Map<String, dynamic> edits,
  )
  onSaveInlineOpeningRowEdits;
  final Future<void> Function() onAddOpeningRow;
  final Future<void> Function(Map<String, dynamic> payload)
  onAddInlineOpeningRow;
  final Future<void> Function(Map<String, dynamic> row) onDeleteOpeningRow;
  final Future<void> Function(List<Map<String, dynamic>> rows)
  onBulkEditOpeningRows;
  final Future<void> Function(List<Map<String, dynamic>> rows)
  onBulkDeleteOpeningRows;

  const _InventoryMonthlyCutBody({
    required this.sites,
    required this.selectedSite,
    required this.periodMonth,
    required this.cutRow,
    required this.openingBalanceRows,
    required this.openingTemplateRows,
    required this.suggestedClosingRows,
    required this.commercialMaterials,
    required this.generalMaterials,
    required this.commercialSourceRulesByCode,
    required this.getOpeningBalanceRows,
    required this.actionBusy,
    required this.onSiteChanged,
    required this.onPeriodMonthChanged,
    required this.onGenerate,
    required this.onRegenerate,
    required this.onLock,
    required this.onUnlock,
    required this.onEditOpeningRow,
    required this.onSaveInlineOpeningRowEdits,
    required this.onAddOpeningRow,
    required this.onAddInlineOpeningRow,
    required this.onDeleteOpeningRow,
    required this.onBulkEditOpeningRows,
    required this.onBulkDeleteOpeningRows,
  });

  @override
  Widget build(BuildContext context) {
    final status = _normalizeMonthlyCutStatus(cutRow?['status']?.toString());
    final isLocked = _isMonthlyCutLockedStatus(status);
    final hasSite = selectedSite != null && selectedSite!.trim().isNotEmpty;
    final previousMonthNegativeRows = suggestedClosingRows.where((row) {
      final onHand = _num(row['on_hand_kg']) ?? 0;
      return onHand < 0;
    }).toList();
    final hasPreviousMonthNegatives = previousMonthNegativeRows.isNotEmpty;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _SectionCard(
          title: '',
          subtitle: '',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _MonthDropdownField(
                    value: periodMonth,
                    width: 220,
                    onChanged: onPeriodMonthChanged,
                  ),
                  _CutStatusBadge(
                    status: status,
                    openingCount: openingBalanceRows.length,
                    generatedAt: cutRow?['generated_at'],
                    lockedAt: cutRow?['locked_at'],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    style: _cutFilledButtonStyle(),
                    onPressed:
                        (!hasSite ||
                            actionBusy != null ||
                            hasPreviousMonthNegatives)
                        ? null
                        : onGenerate,
                    icon: actionBusy == 'generate'
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high_rounded),
                    label: const Text('Generar corte'),
                  ),
                  OutlinedButton.icon(
                    style: _cutOutlinedButtonStyle(),
                    onPressed:
                        (!hasSite ||
                            isLocked ||
                            actionBusy != null ||
                            hasPreviousMonthNegatives)
                        ? null
                        : onRegenerate,
                    icon: actionBusy == 'regenerate'
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.restart_alt_rounded),
                    label: const Text('Regenerar'),
                  ),
                  OutlinedButton.icon(
                    style: _cutOutlinedButtonStyle(),
                    onPressed: (!hasSite || isLocked || actionBusy != null)
                        ? null
                        : onLock,
                    icon: actionBusy == 'lock'
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_outline_rounded),
                    label: const Text('Bloquear'),
                  ),
                  OutlinedButton.icon(
                    style: _cutOutlinedButtonStyle(),
                    onPressed: (!hasSite || !isLocked || actionBusy != null)
                        ? null
                        : onUnlock,
                    icon: actionBusy == 'unlock'
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_open_rounded),
                    label: const Text('Desbloquear'),
                  ),
                  OutlinedButton.icon(
                    style: _cutOutlinedButtonStyle(),
                    onPressed: (!hasSite || isLocked || actionBusy != null)
                        ? null
                        : () => _openOpeningDialog(context, isLocked: isLocked),
                    icon: const Icon(Icons.view_sidebar_rounded),
                    label: const Text('Apertura'),
                  ),
                ],
              ),
              if (hasPreviousMonthNegatives) ...[
                const SizedBox(height: 12),
                _PreviousMonthNegativeWarning(rows: previousMonthNegativeRows),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Reportes de apertura',
          subtitle: '',
          child: _CutOpeningReportsTabs(
            rows: openingBalanceRows,
            suggestedClosingRows: suggestedClosingRows,
            commercialMaterials: commercialMaterials,
          ),
        ),
      ],
    );
  }

  Future<void> _openOpeningDialog(
    BuildContext context, {
    required bool isLocked,
  }) async {
    var dialogRows = openingBalanceRows;
    if (!context.mounted) return;
    while (true) {
      if (!context.mounted) break;
      final action = await showDialog<_OpeningDialogAction>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.22),
        builder: (dialogContext) {
          final commercialLabelsByCode = <String, String>{
            for (final item in commercialMaterials) item.code: item.name,
          };
          return _OpeningBalancesFloatingDialog(
            rows: dialogRows,
            commercialLabelsByCode: commercialLabelsByCode,
            editable: !isLocked,
            onAddRow: onAddOpeningRow,
            commercialMaterials: commercialMaterials,
            generalMaterials: generalMaterials,
            commercialSourceRulesByCode: commercialSourceRulesByCode,
            openingTemplateRows: openingTemplateRows,
            onEditRow: onEditOpeningRow,
            onSaveInlineRowEdits: onSaveInlineOpeningRowEdits,
            onDeleteRow: onDeleteOpeningRow,
          );
        },
      );
      if (!context.mounted ||
          action == null ||
          action.kind == _OpeningDialogActionKind.close) {
        break;
      }
      switch (action.kind) {
        case _OpeningDialogActionKind.add:
          final payload = action.payload;
          if (payload == null) {
            await onAddOpeningRow();
          } else {
            await onAddInlineOpeningRow(payload);
          }
          dialogRows = getOpeningBalanceRows();
          break;
        case _OpeningDialogActionKind.edit:
          final row = action.row;
          if (row != null) {
            await onEditOpeningRow(row);
            dialogRows = getOpeningBalanceRows();
          }
          break;
        case _OpeningDialogActionKind.inlineSave:
          final row = action.row;
          final payload = action.payload;
          if (row != null && payload != null) {
            await onSaveInlineOpeningRowEdits(row, payload);
            dialogRows = getOpeningBalanceRows();
          }
          break;
        case _OpeningDialogActionKind.delete:
          final row = action.row;
          if (row != null) {
            await onDeleteOpeningRow(row);
            dialogRows = getOpeningBalanceRows();
          }
          break;
        case _OpeningDialogActionKind.bulkEdit:
          final rows = action.rows;
          if (rows != null && rows.isNotEmpty) {
            await onBulkEditOpeningRows(rows);
            dialogRows = getOpeningBalanceRows();
          }
          break;
        case _OpeningDialogActionKind.bulkDelete:
          final rows = action.rows;
          if (rows != null && rows.isNotEmpty) {
            await onBulkDeleteOpeningRows(rows);
            dialogRows = getOpeningBalanceRows();
          }
          break;
        case _OpeningDialogActionKind.close:
          break;
      }
    }
  }
}

class _OpeningBalancesFloatingDialog extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final Map<String, String> commercialLabelsByCode;
  final List<_CommercialMaterialOption> commercialMaterials;
  final List<_GeneralMaterialOption> generalMaterials;
  final Map<String, Set<String>> commercialSourceRulesByCode;
  final List<Map<String, dynamic>> openingTemplateRows;
  final bool editable;
  final Future<void> Function() onAddRow;
  final Future<void> Function(Map<String, dynamic> row) onEditRow;
  final Future<void> Function(
    Map<String, dynamic> row,
    Map<String, dynamic> edits,
  )
  onSaveInlineRowEdits;
  final Future<void> Function(Map<String, dynamic> row) onDeleteRow;

  const _OpeningBalancesFloatingDialog({
    required this.rows,
    required this.commercialLabelsByCode,
    required this.commercialMaterials,
    required this.generalMaterials,
    required this.commercialSourceRulesByCode,
    required this.openingTemplateRows,
    required this.editable,
    required this.onAddRow,
    required this.onEditRow,
    required this.onSaveInlineRowEdits,
    required this.onDeleteRow,
  });

  @override
  State<_OpeningBalancesFloatingDialog> createState() =>
      _OpeningBalancesFloatingDialogState();
}

class _OpeningBalancesFloatingDialogState
    extends State<_OpeningBalancesFloatingDialog> {
  final Set<String> _selectedIds = <String>{};
  final Map<String, GlobalKey<_OpeningBalancesDataRowState>> _rowKeys =
      <String, GlobalKey<_OpeningBalancesDataRowState>>{};
  final FocusNode _gridFocusNode = FocusNode(debugLabel: 'opening-grid');
  final FocusNode _insertFocusNode = FocusNode(
    debugLabel: 'opening-insert-row',
  );
  final FocusNode _insertKgFocusNode = FocusNode(
    debugLabel: 'opening-insert-kg',
  );
  final ScrollController _tableVerticalScroll = ScrollController();
  final ScrollController _tableHorizontalScroll = ScrollController();
  int _activeRowIndex = 0;
  int _activeInsertColumn = 0;
  int? _selectionAnchorRowIndex;
  bool _insertRowActive = true;
  String _materialFilter = '';
  String _commercialFilter = '';
  String _kgFilter = '';
  String _sourceFilter = '';
  final Map<String, Set<String>> _openingColumnValueFilters =
      <String, Set<String>>{};
  late final TextEditingController _materialFilterC;
  late final TextEditingController _commercialFilterC;
  late final TextEditingController _kgFilterC;
  late final TextEditingController _sourceFilterC;
  String _insertMaterial = _kInventoryMaterials.first.value;
  String? _insertCommercialCode;
  late final TextEditingController _insertKgC;

  @override
  void initState() {
    super.initState();
    _materialFilterC = TextEditingController();
    _commercialFilterC = TextEditingController();
    _kgFilterC = TextEditingController();
    _sourceFilterC = TextEditingController();
    _insertKgC = TextEditingController(text: '0');
    _insertFocusNode.addListener(_syncInsertRowFocusState);
    _insertKgFocusNode.addListener(_syncInsertRowFocusState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.editable) return;
      _insertFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _insertFocusNode.removeListener(_syncInsertRowFocusState);
    _insertKgFocusNode.removeListener(_syncInsertRowFocusState);
    _insertFocusNode.dispose();
    _insertKgFocusNode.dispose();
    _materialFilterC.dispose();
    _commercialFilterC.dispose();
    _kgFilterC.dispose();
    _sourceFilterC.dispose();
    _insertKgC.dispose();
    _gridFocusNode.dispose();
    _tableVerticalScroll.dispose();
    _tableHorizontalScroll.dispose();
    super.dispose();
  }

  void _syncInsertRowFocusState() {
    if (!mounted) return;
    final next = _insertFocusNode.hasFocus || _insertKgFocusNode.hasFocus;
    var shouldSetState = false;
    if (next != _insertRowActive) {
      _insertRowActive = next;
      shouldSetState = true;
    }
    if (_insertKgFocusNode.hasFocus && _activeInsertColumn != 2) {
      _activeInsertColumn = 2;
      shouldSetState = true;
    }
    if (shouldSetState) {
      setState(() {});
    }
  }

  bool _isEditableTextFocusedInOpeningGrid() {
    final focused = FocusManager.instance.primaryFocus;
    final ctx = focused?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool get _insertCanSubmit =>
      widget.editable && (_parseDouble(_insertKgC.text) ?? -1) >= 0;

  void _setActiveInsertColumn(int value, {bool requestFocus = true}) {
    setState(() {
      _activeInsertColumn = value.clamp(0, 3);
      _selectedIds.clear();
      _selectionAnchorRowIndex = null;
    });
    if (!requestFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_activeInsertColumn == 2) {
        FocusScope.of(context).requestFocus(_insertKgFocusNode);
        return;
      }
      FocusManager.instance.primaryFocus?.unfocus();
      _insertFocusNode.requestFocus();
    });
  }

  void _moveInsertColumn(int delta) {
    const cols = <int>[0, 1, 2, 3];
    final currentIdx = cols.indexOf(_activeInsertColumn);
    final nextIdx = (currentIdx + delta).clamp(0, cols.length - 1);
    _setActiveInsertColumn(cols[nextIdx]);
  }

  void _focusGridFromInsert() {
    if (_visibleRows.isEmpty) return;
    _selectSingleRow(0);
    _gridFocusNode.requestFocus();
  }

  void _focusInsertRowFromGrid() {
    if (!widget.editable) return;
    _gridFocusNode.unfocus();
    _insertFocusNode.requestFocus();
    setState(() {
      _activeInsertColumn = 0;
      _selectedIds.clear();
      _selectionAnchorRowIndex = null;
    });
  }

  void _activateInsertKgField() {
    if (!widget.editable) return;
    _setActiveInsertColumn(2, requestFocus: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_insertKgFocusNode);
      _insertKgC.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _insertKgC.text.length,
      );
    });
  }

  void _clearGridSelectionForInsertRow() {
    if (_selectedIds.isEmpty && _selectionAnchorRowIndex == null) return;
    setState(() {
      _selectedIds.clear();
      _selectionAnchorRowIndex = null;
    });
  }

  @override
  void didUpdateWidget(covariant _OpeningBalancesFloatingDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    final validIds = widget.rows
        .map((r) => (r['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    _selectedIds.removeWhere((id) => !validIds.contains(id));
    if (_visibleRows.isEmpty) {
      _activeRowIndex = 0;
      _selectionAnchorRowIndex = null;
    } else if (_activeRowIndex >= _visibleRows.length) {
      _activeRowIndex = _visibleRows.length - 1;
    }
  }

  List<_CommercialMaterialOption> get _insertCommercialOptions {
    final insertMaterialKey = _normalizeOpeningKey(_insertMaterial);
    final templateRows =
        widget.openingTemplateRows.where((r) {
          final material = _normalizeOpeningKey(
            (r['material'] ?? '').toString(),
          );
          final active = r['is_active'] == null
              ? true
              : (r['is_active'] == true);
          return active && material == insertMaterialKey;
        }).toList()..sort((a, b) {
          final ao = (a['sort_order'] as num?)?.toInt() ?? 999999;
          final bo = (b['sort_order'] as num?)?.toInt() ?? 999999;
          final byOrder = ao.compareTo(bo);
          if (byOrder != 0) return byOrder;
          return (a['commercial_material_code'] ?? '').toString().compareTo(
            (b['commercial_material_code'] ?? '').toString(),
          );
        });

    if (templateRows.isNotEmpty) {
      final codes = templateRows
          .map((r) => (r['commercial_material_code'] ?? '').toString().trim())
          .where((c) => c.isNotEmpty)
          .toList();
      final byCode = <String, _CommercialMaterialOption>{
        for (final c in widget.commercialMaterials)
          _normalizeOpeningKey(c.code): c,
      };
      final templated = <_CommercialMaterialOption>[];
      final seen = <String>{};
      for (final code in codes) {
        final key = _normalizeOpeningKey(code);
        final opt = byCode[key];
        if (opt != null && seen.add(key)) templated.add(opt);
      }
      final compatible =
          widget.commercialMaterials
              .where(
                (c) =>
                    _openingCommercialMatchesInsertMaterial(c, _insertMaterial),
              )
              .toList()
            ..sort((a, b) {
              final byName = _normalizeSortKey(
                a.name,
              ).compareTo(_normalizeSortKey(b.name));
              if (byName != 0) return byName;
              return a.code.compareTo(b.code);
            });
      for (final opt in compatible) {
        final key = _normalizeOpeningKey(opt.code);
        if (seen.add(key)) templated.add(opt);
      }
      return templated;
    }

    final filtered = widget.commercialMaterials
        .where(
          (c) => _openingCommercialMatchesInsertMaterial(c, _insertMaterial),
        )
        .toList();
    filtered.sort((a, b) {
      final byName = _normalizeSortKey(
        a.name,
      ).compareTo(_normalizeSortKey(b.name));
      if (byName != 0) return byName;
      return a.code.compareTo(b.code);
    });
    return filtered;
  }

  bool _openingCommercialMatchesInsertMaterial(
    _CommercialMaterialOption option,
    String insertMaterial,
  ) {
    return _commercialMatchesInventoryMaterial(
      option: option,
      selectedMaterial: insertMaterial,
      generalMaterials: widget.generalMaterials,
      commercialSourceRulesByCode: widget.commercialSourceRulesByCode,
    );
  }

  String _normalizeOpeningKey(String value) => value.trim().toUpperCase();

  bool _isGeneratedTotalRow(Map<String, dynamic> row) {
    final source = _normalizeOpeningKey((row['source'] ?? '').toString());
    final code = (row['commercial_material_code'] ?? '').toString().trim();
    return source == 'GENERATED_TOTAL' && code.isEmpty;
  }

  bool _isTemplateSeedRow(Map<String, dynamic> row) {
    final source = _normalizeOpeningKey((row['source'] ?? '').toString());
    return source == 'TEMPLATE_SEED';
  }

  bool _materialHasTemplateRows(String material) {
    final key = _normalizeOpeningKey(material);
    for (final row in widget.rows) {
      if (_normalizeOpeningKey((row['material'] ?? '').toString()) != key) {
        continue;
      }
      if (_isTemplateSeedRow(row)) return true;
      final code = (row['commercial_material_code'] ?? '').toString().trim();
      if (code.isNotEmpty) return true;
    }
    return false;
  }

  List<String> get _undistributedTotalMaterialLabels {
    final labels = <String>{};
    for (final row in widget.rows) {
      if (!_isGeneratedTotalRow(row)) continue;
      final material = (row['material'] ?? '').toString();
      if (material.isEmpty) continue;
      if (_materialHasTemplateRows(material)) {
        labels.add(_materialLabel(material));
      }
    }
    final out = labels.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  List<Map<String, dynamic>> get _visibleRows {
    final materialQ = _materialFilter.trim().toLowerCase();
    final commercialQ = _commercialFilter.trim().toLowerCase();
    final kgQ = _kgFilter.trim().toLowerCase();
    final sourceQ = _sourceFilter.trim().toLowerCase();
    return widget.rows.where((row) {
      for (final entry in _openingColumnValueFilters.entries) {
        if (entry.value.isEmpty) continue;
        final value = _openingFilterValueForRow(entry.key, row);
        if (!entry.value.contains(value)) return false;
      }
      if (materialQ.isNotEmpty) {
        final label = _materialLabel(row['material']?.toString()).toLowerCase();
        final raw = (row['material'] ?? '').toString().toLowerCase();
        if (!label.contains(materialQ) && !raw.contains(materialQ)) {
          return false;
        }
      }
      if (commercialQ.isNotEmpty) {
        final code = (row['commercial_material_code'] ?? '').toString().trim();
        final label = code.isEmpty
            ? ''
            : (widget.commercialLabelsByCode[code] ?? code).toLowerCase();
        if (!label.contains(commercialQ) &&
            !code.toLowerCase().contains(commercialQ)) {
          return false;
        }
      }
      if (kgQ.isNotEmpty) {
        final kgText = _formatKg(_num(row['weight_kg'])).toLowerCase();
        if (!kgText.contains(kgQ)) return false;
      }
      if (sourceQ.isNotEmpty) {
        final source = (row['source'] ?? '').toString().toLowerCase();
        final sourceLabel = _openingSourceUiLabel(row).toLowerCase();
        if (!source.contains(sourceQ) && !sourceLabel.contains(sourceQ)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  String _openingFilterValueForRow(String columnId, Map<String, dynamic> row) {
    switch (columnId) {
      case 'material':
        return _materialLabel(row['material']?.toString());
      case 'commercial':
        final code = (row['commercial_material_code'] ?? '').toString().trim();
        if (code.isEmpty) return 'Sin material comercial';
        return widget.commercialLabelsByCode[code] ?? code;
      case 'kg':
        return _formatKg(_num(row['weight_kg']));
      case 'source':
        return _openingSourceUiLabel(row);
      default:
        return '';
    }
  }

  List<String> _openingColumnDistinctValues(
    String columnId, {
    String search = '',
  }) {
    final q = search.trim().toLowerCase();
    final values = <String>{};
    for (final row in widget.rows) {
      final value = _openingFilterValueForRow(columnId, row).trim();
      if (value.isEmpty) continue;
      if (q.isNotEmpty && !value.toLowerCase().contains(q)) continue;
      values.add(value);
    }
    final sorted = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  void _syncStateToVisibleRows() {
    final visibleIds = _visibleRows
        .map((r) => (r['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    _selectedIds.removeWhere((id) => !visibleIds.contains(id));
    if (_visibleRows.isEmpty) {
      _activeRowIndex = 0;
      _selectionAnchorRowIndex = null;
      return;
    }
    if (_activeRowIndex >= _visibleRows.length) {
      _activeRowIndex = _visibleRows.length - 1;
    }
    if (_selectionAnchorRowIndex != null &&
        _selectionAnchorRowIndex! >= _visibleRows.length) {
      _selectionAnchorRowIndex = _activeRowIndex;
    }
  }

  bool _hasOpeningActiveFilter(String key) {
    return (_openingColumnValueFilters[key]?.isNotEmpty ?? false) ||
        switch (key) {
          'material' => _materialFilter.trim().isNotEmpty,
          'commercial' => _commercialFilter.trim().isNotEmpty,
          'kg' => _kgFilter.trim().isNotEmpty,
          'source' => _sourceFilter.trim().isNotEmpty,
          _ => false,
        };
  }

  Future<void> _openOpeningColumnFilter(String key, String label) async {
    final initialSelected = {
      ...(_openingColumnValueFilters[key] ?? <String>{}),
    };
    final result = await showDialog<Set<String>?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (dialogContext) {
        final localSelected = <String>{...initialSelected};
        String localSearch = '';
        return StatefulBuilder(
          builder: (_, setLocalState) {
            final options = _openingColumnDistinctValues(
              key,
              search: localSearch,
            );
            final allVisibleSelected =
                options.isNotEmpty && options.every(localSelected.contains);

            void applyAndClose() {
              Navigator.pop(dialogContext, <String>{...localSelected});
            }

            return Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                final k = event.logicalKey;
                if (k == LogicalKeyboardKey.escape) {
                  Navigator.pop(dialogContext);
                  return KeyEventResult.handled;
                }
                if (k == LogicalKeyboardKey.enter ||
                    k == LogicalKeyboardKey.numpadEnter) {
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
                      decoration: _inventoryFilterDialogDecoration(),
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
                            autofocus: true,
                            onChanged: (v) =>
                                setLocalState(() => localSearch = v),
                            onSubmitted: (_) => applyAndClose(),
                            decoration: _openingFilterSearchDecoration(
                              hintText: 'Buscar',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF375D5B),
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
                                : ListView.builder(
                                    itemCount: options.length,
                                    itemBuilder: (_, i) {
                                      final value = options[i];
                                      final checked = localSelected.contains(
                                        value,
                                      );
                                      return CheckboxListTile(
                                        dense: true,
                                        value: checked,
                                        activeColor: const Color(0xFF5A9C9A),
                                        checkColor: Colors.white,
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        title: Text(
                                          value,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: checked
                                                ? const Color(0xFF1B6C69)
                                                : const Color(0xFF0B2B2B),
                                            fontWeight: checked
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                        onChanged: (v) {
                                          setLocalState(() {
                                            if (v ?? false) {
                                              localSelected.add(value);
                                            } else {
                                              localSelected.remove(value);
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
                                style: _cutOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: _cutOutlinedButtonStyle(),
                                onPressed: () =>
                                    Navigator.pop(dialogContext, <String>{}),
                                child: const Text('Limpiar'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: _cutFilledButtonStyle(),
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
            );
          },
        );
      },
    );
    if (!mounted || result == null) return;
    setState(() {
      if (result.isEmpty) {
        _openingColumnValueFilters.remove(key);
      } else {
        _openingColumnValueFilters[key] = result;
      }
      switch (key) {
        case 'material':
          _materialFilter = '';
          _materialFilterC.clear();
          break;
        case 'commercial':
          _commercialFilter = '';
          _commercialFilterC.clear();
          break;
        case 'kg':
          _kgFilter = '';
          _kgFilterC.clear();
          break;
        case 'source':
          _sourceFilter = '';
          _sourceFilterC.clear();
          break;
      }
      _syncStateToVisibleRows();
    });
  }

  Future<void> _pickInsertMaterial() async {
    if (!widget.editable) return;
    final selected = await _showOpeningSingleSelectDialog<String>(
      title: 'Seleccionar',
      searchHint: 'Buscar',
      options: _kInventoryMaterials.map((m) => m.value).toList(),
      selectedValue: _insertMaterial,
      labelFor: (v) =>
          _kInventoryMaterials.firstWhere((m) => m.value == v).label,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _insertMaterial = selected;
      final exists = _insertCommercialOptions.any(
        (opt) => opt.code == _insertCommercialCode,
      );
      if (!exists) _insertCommercialCode = null;
    });
  }

  Future<void> _pickInsertCommercial() async {
    if (!widget.editable) return;
    final options = _insertCommercialOptions;
    final selected = await _showOpeningSingleSelectDialog<String?>(
      title: 'Seleccionar',
      searchHint: 'Buscar',
      options: <String?>[null, ...options.map((o) => o.code)],
      selectedValue: _insertCommercialCode,
      labelFor: (v) => v == null
          ? 'Sin material comercial'
          : (widget.commercialLabelsByCode[v] ?? v),
    );
    if (!mounted) return;
    setState(() => _insertCommercialCode = selected);
  }

  Future<T?> _showOpeningSingleSelectDialog<T>({
    required String title,
    required String searchHint,
    required List<T> options,
    required T? selectedValue,
    required String Function(T value) labelFor,
  }) async {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (dialogContext) {
        String localSearch = '';
        return StatefulBuilder(
          builder: (_, setLocalState) {
            final visible = options.where((opt) {
              final label = labelFor(opt).toLowerCase();
              final q = localSearch.trim().toLowerCase();
              return q.isEmpty || label.contains(q);
            }).toList();
            return Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.pop(dialogContext);
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
                      constraints: const BoxConstraints(maxHeight: 620),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      decoration: _inventoryFilterDialogDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0B2B2B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            autofocus: true,
                            onChanged: (v) =>
                                setLocalState(() => localSearch = v),
                            decoration: _openingFilterSearchDecoration(
                              hintText: searchHint,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (_, i) {
                                final item = visible[i];
                                final checked = item == selectedValue;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  hoverColor: const Color(
                                    0xFF0B72FF,
                                  ).withValues(alpha: 0.06),
                                  onTap: () =>
                                      Navigator.pop(dialogContext, item),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            labelFor(item),
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: checked
                                                  ? const Color(0xFF1F8F8A)
                                                  : const Color(0xFF0B2B2B),
                                              fontWeight: checked
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (checked)
                                          const Icon(
                                            Icons.check_rounded,
                                            color: Color(0xFF0B72FF),
                                          ),
                                      ],
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _activateInsertCellFromKeyboard() async {
    var keepInsertRowFocus = true;
    switch (_activeInsertColumn) {
      case 0:
        await _pickInsertMaterial();
        break;
      case 1:
        await _pickInsertCommercial();
        break;
      case 2:
        keepInsertRowFocus = false;
        _activateInsertKgField();
        break;
      case 3:
        if (_insertCanSubmit) await _submitInsertRow();
        break;
    }
    if (mounted && keepInsertRowFocus) _insertFocusNode.requestFocus();
  }

  Future<void> _submitInsertRow() async {
    if (!widget.editable) return;
    final weight = _parseDouble(_insertKgC.text);
    if (weight == null || weight < 0) return;
    final payload = <String, dynamic>{
      'material': _insertMaterial,
      'commercial_material_code': _insertCommercialCode,
      'weight_kg': weight,
      'notes': null,
    };
    if (!mounted) return;
    Navigator.pop(context, _OpeningDialogAction.add(payload));
  }

  List<Map<String, dynamic>> get _selectedRows {
    if (_selectedIds.isEmpty) return const [];
    return _visibleRows
        .where((r) => _selectedIds.contains((r['id'] ?? '').toString()))
        .toList();
  }

  bool _isCtrlOrCmdPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
  }

  String _rowIdAt(int rowIndex) =>
      (_visibleRows[rowIndex]['id'] ?? '').toString();

  GlobalKey<_OpeningBalancesDataRowState> _rowKeyFor(String rowId) =>
      _rowKeys.putIfAbsent(
        rowId,
        () => GlobalKey<_OpeningBalancesDataRowState>(debugLabel: rowId),
      );

  _OpeningBalancesDataRowState? _selectedRowState() {
    if (_visibleRows.isEmpty) return null;
    final row = _visibleRows[_activeRowIndex];
    final rowId = (row['id'] ?? '').toString();
    return rowId.isEmpty ? null : _rowKeys[rowId]?.currentState;
  }

  List<_OpeningBalancesDataRowState> _selectedRowStates() {
    if (_selectedIds.isEmpty) {
      final s = _selectedRowState();
      return s == null ? const [] : [s];
    }
    final out = <_OpeningBalancesDataRowState>[];
    for (final row in _visibleRows) {
      final id = (row['id'] ?? '').toString();
      if (id.isEmpty || !_selectedIds.contains(id)) continue;
      final s = _rowKeys[id]?.currentState;
      if (s != null) out.add(s);
    }
    return out;
  }

  bool _hasAnySelectedInlineEditing() =>
      _selectedRowStates().any((s) => s.isInlineEditing);

  void _moveActiveRowKeepingSelection(int delta) {
    if (_visibleRows.isEmpty) return;
    final next = (_activeRowIndex + delta).clamp(0, _visibleRows.length - 1);
    if (next == _activeRowIndex) return;
    setState(() => _activeRowIndex = next);
    _ensureActiveRowVisible();
  }

  void _startInlineEditForCurrentSelection() {
    if (!widget.editable) return;
    final selectedRows = _selectedRows;
    if (selectedRows.length <= 1) {
      _selectedRowState()?.startInlineEdit(requestFocus: false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _selectedRowState()?.focusInlineKgField();
      });
      return;
    }
    final states = _selectedRowStates();
    for (final s in states) {
      s.startInlineEdit(requestFocus: false);
    }
    _selectedRowState()?.focusInlineKgField();
  }

  void _cancelInlineEditForCurrentSelection() {
    final states = _selectedRowStates();
    if (states.isEmpty) {
      _selectedRowState()?.cancelInlineEdit();
    } else {
      for (final s in states) {
        s.cancelInlineEdit();
      }
    }
    _gridFocusNode.requestFocus();
  }

  void _selectSingleRow(int rowIndex) {
    if (rowIndex < 0 || rowIndex >= _visibleRows.length) return;
    final id = _rowIdAt(rowIndex);
    setState(() {
      _activeRowIndex = rowIndex;
      _selectionAnchorRowIndex = rowIndex;
      _selectedIds
        ..clear()
        ..addAll(id.isEmpty ? const <String>[] : [id]);
    });
    _ensureActiveRowVisible();
  }

  void _toggleRowSelectionAt(int rowIndex) {
    if (rowIndex < 0 || rowIndex >= _visibleRows.length) return;
    final id = _rowIdAt(rowIndex);
    if (id.isEmpty) return;
    setState(() {
      _activeRowIndex = rowIndex;
      _selectionAnchorRowIndex ??= rowIndex;
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
    _ensureActiveRowVisible();
  }

  void _extendSelectionTo(int rowIndex) {
    if (_visibleRows.isEmpty) return;
    final clamped = rowIndex.clamp(0, _visibleRows.length - 1);
    final anchor = _selectionAnchorRowIndex ?? _activeRowIndex;
    final start = anchor < clamped ? anchor : clamped;
    final end = anchor < clamped ? clamped : anchor;
    setState(() {
      _activeRowIndex = clamped;
      _selectionAnchorRowIndex = anchor;
      _selectedIds.clear();
      for (var i = start; i <= end; i++) {
        final id = _rowIdAt(i);
        if (id.isNotEmpty) _selectedIds.add(id);
      }
    });
    _ensureActiveRowVisible();
  }

  void _moveActiveRow(int delta, {required bool extendSelection}) {
    if (_visibleRows.isEmpty) return;
    final next = (_activeRowIndex + delta).clamp(0, _visibleRows.length - 1);
    if (next == _activeRowIndex) return;
    if (extendSelection) {
      _extendSelectionTo(next);
    } else {
      _selectSingleRow(next);
    }
  }

  void _handleRowClick(int rowIndex) {
    if (_isCtrlOrCmdPressed()) {
      _toggleRowSelectionAt(rowIndex);
    } else {
      final rowId = _rowIdAt(rowIndex);
      final preserveMultiSelection =
          _selectedIds.length > 1 &&
          rowId.isNotEmpty &&
          _selectedIds.contains(rowId);
      if (preserveMultiSelection) {
        setState(() => _activeRowIndex = rowIndex);
        _ensureActiveRowVisible();
        return;
      }
      _selectSingleRow(rowIndex);
    }
  }

  void _handleCellClick(int rowIndex, int colIndex) {
    if (widget.editable && colIndex == 2) {
      _activateInlineKgEdit(rowIndex);
      return;
    }
    _handleRowClick(rowIndex);
    _gridFocusNode.requestFocus();
  }

  void _setActiveRowPreservingCurrentSelection(int rowIndex) {
    if (rowIndex < 0 || rowIndex >= _visibleRows.length) return;
    setState(() {
      _activeRowIndex = rowIndex;
      _selectionAnchorRowIndex ??= rowIndex;
    });
    _ensureActiveRowVisible();
  }

  Future<void> _handleRowContextMenu(
    int rowIndex,
    TapDownDetails details,
  ) async {
    if (rowIndex < 0 || rowIndex >= _visibleRows.length) return;
    final rowId = _rowIdAt(rowIndex);
    if (rowId.isEmpty) return;

    if (_selectedIds.contains(rowId)) {
      _setActiveRowPreservingCurrentSelection(rowIndex);
    } else {
      _selectSingleRow(rowIndex);
    }
    _gridFocusNode.requestFocus();

    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;
    final menuPosition = RelativeRect.fromRect(
      Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );

    final selectedRows = _selectedRows;
    final editingInline = _hasAnySelectedInlineEditing();
    final action = await showMenu<String>(
      context: context,
      position: menuPosition,
      color: const Color(0xE6F2F7F6),
      items: [
        if (editingInline) ...[
          const PopupMenuItem<String>(value: 'save', child: Text('GUARDAR')),
          const PopupMenuItem<String>(value: 'cancel', child: Text('CANCELAR')),
          const PopupMenuDivider(),
        ] else if (widget.editable) ...[
          PopupMenuItem<String>(
            value: 'edit',
            child: Text(
              selectedRows.length > 1 ? 'EDITAR SELECCIONADAS' : 'EDITAR',
            ),
          ),
          const PopupMenuDivider(),
        ],
        if (widget.editable)
          PopupMenuItem<String>(
            value: 'delete',
            child: Text(
              selectedRows.length > 1
                  ? 'ELIMINAR (${selectedRows.length})'
                  : 'ELIMINAR',
            ),
          ),
      ],
    );

    switch (action) {
      case 'edit':
        _startInlineEditForCurrentSelection();
        break;
      case 'save':
        _selectedRowState()?.submitInlineEdit();
        break;
      case 'cancel':
        _cancelInlineEditForCurrentSelection();
        break;
      case 'delete':
        if (!widget.editable) break;
        final currentSelectedRows = _selectedRows;
        if (currentSelectedRows.length > 1) {
          if (!mounted) return;
          Navigator.pop(
            context,
            _OpeningDialogAction.bulkDelete(currentSelectedRows),
          );
        } else {
          final row = currentSelectedRows.isNotEmpty
              ? currentSelectedRows.first
              : _visibleRows[_activeRowIndex];
          if (!mounted) return;
          Navigator.pop(context, _OpeningDialogAction.delete(row));
        }
        break;
    }
  }

  void _activateInlineKgEdit(int rowIndex) {
    if (rowIndex < 0 || rowIndex >= _visibleRows.length) return;
    final rowId = _rowIdAt(rowIndex);
    final hasSelectionGroupContext =
        _selectedIds.length > 1 || _hasAnySelectedInlineEditing();

    if (hasSelectionGroupContext &&
        rowId.isNotEmpty &&
        !_selectedIds.contains(rowId)) {
      setState(() {
        _activeRowIndex = rowIndex;
        _selectionAnchorRowIndex ??= rowIndex;
        _selectedIds.add(rowId);
      });
      _ensureActiveRowVisible();
      _startInlineEditForCurrentSelection();
      return;
    }

    if (hasSelectionGroupContext &&
        rowId.isNotEmpty &&
        _selectedIds.contains(rowId)) {
      setState(() => _activeRowIndex = rowIndex);
      _ensureActiveRowVisible();
    } else {
      _handleRowClick(rowIndex);
    }
    _startInlineEditForCurrentSelection();
  }

  void _handleEditableKgCellDoubleTap(int rowIndex) {
    _activateInlineKgEdit(rowIndex);
  }

  void _ensureActiveRowVisible() {
    if (!_tableVerticalScroll.hasClients || _visibleRows.isEmpty) return;
    final topOffset =
        _kOpeningTableScrollPaddingTop +
        _kOpeningTableHeaderHeight +
        (widget.editable
            ? _kOpeningTableMetaRowGap + _kOpeningTableInsertRowHeight
            : 0) +
        _kOpeningTableHeaderGap;
    const rowExtent = _kOpeningTableRowExtent;
    final rowTop = topOffset + (_activeRowIndex * rowExtent);
    final rowBottom = rowTop + _kOpeningTableRowVisualHeight;
    final viewportTop = _tableVerticalScroll.offset;
    final viewportBottom =
        viewportTop + _tableVerticalScroll.position.viewportDimension;
    double? target;
    if (rowTop < viewportTop) {
      target = rowTop - 8;
    } else if (rowBottom > viewportBottom) {
      target = rowBottom - _tableVerticalScroll.position.viewportDimension + 8;
    }
    if (target == null) return;
    final clamped = target.clamp(
      _tableVerticalScroll.position.minScrollExtent,
      _tableVerticalScroll.position.maxScrollExtent,
    );
    _tableVerticalScroll.jumpTo(clamped.toDouble());
  }

  KeyEventResult _handleGridKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isEditableTextFocusedInOpeningGrid()) {
      return KeyEventResult.ignored;
    }
    if (_visibleRows.isEmpty) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.pop(context, const _OpeningDialogAction.close());
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final ctrlOrCmd = _isCtrlOrCmdPressed();
    final key = event.logicalKey;
    final selectedState = _selectedRowState();
    final editingInline = _hasAnySelectedInlineEditing();
    if (editingInline) {
      if (key == LogicalKeyboardKey.arrowDown) {
        final multiSelected = _selectedRows.length > 1;
        if (multiSelected) {
          _moveActiveRowKeepingSelection(1);
          _selectedRowState()?.startInlineEdit(requestFocus: false);
          _selectedRowState()?.focusInlineKgField();
          return KeyEventResult.handled;
        }
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        final multiSelected = _selectedRows.length > 1;
        if (multiSelected) {
          _moveActiveRowKeepingSelection(-1);
          _selectedRowState()?.startInlineEdit(requestFocus: false);
          _selectedRowState()?.focusInlineKgField();
          return KeyEventResult.handled;
        }
      }
      if (key == LogicalKeyboardKey.escape) {
        _cancelInlineEditForCurrentSelection();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        selectedState?.submitInlineEdit();
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveActiveRow(1, extendSelection: ctrlOrCmd);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (!ctrlOrCmd &&
          widget.editable &&
          _selectedIds.length <= 1 &&
          _activeRowIndex == 0) {
        _focusInsertRowFromGrid();
        return KeyEventResult.handled;
      }
      _moveActiveRow(-1, extendSelection: ctrlOrCmd);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_selectedIds.isNotEmpty) {
        setState(() {
          _selectedIds.clear();
          _selectionAnchorRowIndex = null;
        });
      } else {
        Navigator.pop(context, const _OpeningDialogAction.close());
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      if (!widget.editable) return KeyEventResult.handled;
      final selectedRows = _selectedRows;
      if (selectedRows.length > 1) {
        Navigator.pop(context, _OpeningDialogAction.bulkDelete(selectedRows));
      } else {
        final row = selectedRows.isNotEmpty
            ? selectedRows.first
            : _visibleRows[_activeRowIndex];
        Navigator.pop(context, _OpeningDialogAction.delete(row));
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (!widget.editable) return KeyEventResult.handled;
      _startInlineEditForCurrentSelection();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Widget _buildOpeningInlineInsertRow() {
    final canInsert = _insertCanSubmit;
    String? materialLabel;
    for (final m in _kInventoryMaterials) {
      if (m.value == _insertMaterial) {
        materialLabel = m.label;
        break;
      }
    }
    final commercialLabel = _insertCommercialCode == null
        ? 'Sin material comercial'
        : (widget.commercialLabelsByCode[_insertCommercialCode!] ??
              _insertCommercialCode!);

    Widget frame(int col, Widget child) {
      final active = _insertRowActive && _activeInsertColumn == col;
      if (!active) return child;
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF0B72FF).withValues(alpha: 0.80),
            width: 1.15,
          ),
        ),
        child: child,
      );
    }

    Widget pickCell({
      required int col,
      required double width,
      required String text,
      required VoidCallback onTap,
      bool alignEnd = false,
      IconData? icon,
    }) {
      return frame(
        col,
        SizedBox(
          width: width,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.editable
                ? () {
                    _clearGridSelectionForInsertRow();
                    _setActiveInsertColumn(col, requestFocus: false);
                    _insertFocusNode.requestFocus();
                    onTap();
                  }
                : null,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0B2B2B),
                      ),
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 6),
                    Icon(icon, size: 16, color: const Color(0xFF2A4B49)),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: _insertRowActive ? 2 : 0.4,
      color: _insertRowActive
          ? const Color(0xFFD9ECFA)
          : const Color(0xFFE7F1F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: _insertRowActive
              ? const Color(0xFF3C8DCC).withValues(alpha: 0.55)
              : Colors.transparent,
        ),
      ),
      child: Focus(
        focusNode: _insertFocusNode,
        onKeyEvent: (_, event) {
          if (_isEditableTextFocusedInOpeningGrid()) {
            return KeyEventResult.ignored;
          }
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowLeft) {
            _moveInsertColumn(-1);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight) {
            _moveInsertColumn(1);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp) {
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown) {
            _focusGridFromInsert();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.space) {
            unawaited(_activateInsertCellFromKeyboard());
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter) {
            if (canInsert) {
              unawaited(_submitInsertRow());
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: SizedBox(
          height: _kOpeningTableRowVisualHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                pickCell(
                  col: 0,
                  width: _kOpeningTableMaterialColW,
                  text: materialLabel ?? _insertMaterial,
                  icon: Icons.arrow_drop_down_rounded,
                  onTap: () => unawaited(_pickInsertMaterial()),
                ),
                const SizedBox(width: 4),
                pickCell(
                  col: 1,
                  width: _kOpeningTableCommercialColW,
                  text: commercialLabel,
                  icon: Icons.arrow_drop_down_rounded,
                  onTap: () => unawaited(_pickInsertCommercial()),
                ),
                const SizedBox(width: 4),
                frame(
                  2,
                  SizedBox(
                    width: _kOpeningTableKgColW,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) => _activateInsertKgField(),
                      child: TextField(
                        controller: _insertKgC,
                        focusNode: _insertKgFocusNode,
                        enabled: widget.editable,
                        selectAllOnFocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _openingInlineFieldDecoration(
                          hintText: '0',
                        ),
                        onTap: _activateInsertKgField,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) {
                          if (canInsert) unawaited(_submitInsertRow());
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                pickCell(
                  col: 99,
                  width: _kOpeningTableSourceColW,
                  text: 'manual',
                  onTap: () {},
                ),
                const SizedBox(width: 4),
                pickCell(
                  col: 99,
                  width: _kOpeningTableLockedColW,
                  text: 'No',
                  onTap: () {},
                ),
                const SizedBox(width: 10),
                frame(
                  3,
                  SizedBox(
                    width: _kOpeningTableActionsColW,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Tooltip(
                        message: 'Agregar',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: canInsert
                              ? () => unawaited(_submitInsertRow())
                              : null,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: canInsert
                                  ? const Color(
                                      0xFF19C37D,
                                    ).withValues(alpha: 0.92)
                                  : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.52),
                              ),
                            ),
                            child: Icon(
                              Icons.add,
                              size: 18,
                              color: canInsert
                                  ? Colors.white
                                  : const Color(0xFF0B2B2B),
                            ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRows = _selectedRows;
    final visibleRows = _visibleRows;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 680),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Focus(
              autofocus: false,
              focusNode: _gridFocusNode,
              onKeyEvent: _handleGridKey,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: _inventoryFilterDialogDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.view_sidebar_rounded,
                          color: Color(0xFF0B2B2B),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Apertura',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0B2B2B),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.pop(
                            context,
                            const _OpeningDialogAction.close(),
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    OperationalGlassToolbarPanel(
                      child: Row(
                        children: [
                          if (widget.editable && selectedRows.isNotEmpty) ...[
                            OutlinedButton.icon(
                              style: _inventoryActionOutlinedButtonStyle(),
                              onPressed: _startInlineEditForCurrentSelection,
                              icon: const Icon(Icons.edit_note_rounded),
                              label: Text(
                                selectedRows.length > 1
                                    ? 'Editar fila activa'
                                    : 'Editar',
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              style: _cutFilledButtonStyle(),
                              onPressed: () => Navigator.pop(
                                context,
                                selectedRows.length > 1
                                    ? _OpeningDialogAction.bulkDelete(
                                        selectedRows,
                                      )
                                    : _OpeningDialogAction.delete(
                                        selectedRows.first,
                                      ),
                              ),
                              icon: const Icon(Icons.delete_outline),
                              label: Text(
                                selectedRows.length > 1
                                    ? 'Eliminar (${selectedRows.length})'
                                    : 'Eliminar',
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          const Spacer(),
                          Text(
                            '${widget.rows.length} renglones',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kOperationalMetricMuted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          OperationalSelectionInfo(
                            selectedCount: selectedRows.length,
                            activeCellLabel: null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_undistributedTotalMaterialLabels.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFFF3D6,
                          ).withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFFE4BE72,
                            ).withValues(alpha: 0.7),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: Color(0xFF805C16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Hay totales sin distribuir en: ${_undistributedTotalMaterialLabels.join(', ')}. '
                                'Las filas con origen "Total generado" son el arrastre del mes anterior; distribuye esos kg en los renglones de plantilla para evitar duplicidad operativa.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5C4311),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Expanded(
                      child: _OpeningBalancesTable(
                        rows: visibleRows,
                        emptyMessage: widget.rows.isEmpty
                            ? 'Sin opening_balances para este mes/sitio. Usa "Generar corte" o captura manualmente en base de datos.'
                            : 'Sin resultados con los filtros actuales.',
                        insertRow: widget.editable
                            ? _buildOpeningInlineInsertRow()
                            : null,
                        headerFiltersRow: null,
                        hasActiveHeaderFilter: _hasOpeningActiveFilter,
                        onOpenHeaderFilter: _openOpeningColumnFilter,
                        commercialLabelsByCode: widget.commercialLabelsByCode,
                        rowKeyFor: _rowKeyFor,
                        editable: widget.editable,
                        selectedIds: _selectedIds,
                        activeRowIndex: _activeRowIndex,
                        activeColumnIndex: -1,
                        verticalScrollController: _tableVerticalScroll,
                        horizontalScrollController: _tableHorizontalScroll,
                        onRowTap: _handleRowClick,
                        onCellTap: _handleCellClick,
                        onRowSecondaryTapDown: _handleRowContextMenu,
                        onEditableKgCellDoubleTap:
                            _handleEditableKgCellDoubleTap,
                        onSetActiveRowPreserveSelection: (rowIndex) {
                          if (rowIndex < 0 || rowIndex >= visibleRows.length) {
                            return;
                          }
                          _setActiveRowPreservingCurrentSelection(rowIndex);
                        },
                        onInlineCancelSelection:
                            _cancelInlineEditForCurrentSelection,
                        onEditRow: (row) async {
                          final idx = visibleRows.indexWhere(
                            (r) =>
                                (r['id'] ?? '').toString() ==
                                (row['id'] ?? '').toString(),
                          );
                          if (idx >= 0) {
                            final rowId = (row['id'] ?? '').toString();
                            final preserveMultiSelection =
                                _selectedIds.length > 1 &&
                                rowId.isNotEmpty &&
                                _selectedIds.contains(rowId);
                            if (preserveMultiSelection) {
                              setState(() => _activeRowIndex = idx);
                              _ensureActiveRowVisible();
                              _startInlineEditForCurrentSelection();
                            } else {
                              _selectSingleRow(idx);
                              _rowKeyFor(rowId).currentState?.startInlineEdit();
                            }
                          }
                        },
                        onInlineSaveRow: (row, payload) async {
                          Navigator.pop(
                            context,
                            _OpeningDialogAction.inlineSave(row, payload),
                          );
                        },
                        onDeleteRow: (row) async {
                          Navigator.pop(
                            context,
                            _OpeningDialogAction.delete(row),
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
      ),
    );
  }
}

enum _OpeningDialogActionKind {
  add,
  edit,
  inlineSave,
  delete,
  bulkEdit,
  bulkDelete,
  close,
}

class _OpeningDialogAction {
  final _OpeningDialogActionKind kind;
  final Map<String, dynamic>? row;
  final List<Map<String, dynamic>>? rows;
  final Map<String, dynamic>? payload;

  const _OpeningDialogAction._(this.kind, {this.row, this.rows, this.payload});

  _OpeningDialogAction.add([Map<String, dynamic>? payload])
    : this._(_OpeningDialogActionKind.add, payload: payload);
  const _OpeningDialogAction.close() : this._(_OpeningDialogActionKind.close);
  _OpeningDialogAction.inlineSave(
    Map<String, dynamic> row,
    Map<String, dynamic> payload,
  ) : this._(_OpeningDialogActionKind.inlineSave, row: row, payload: payload);
  _OpeningDialogAction.delete(Map<String, dynamic> row)
    : this._(_OpeningDialogActionKind.delete, row: row);
  _OpeningDialogAction.bulkDelete(List<Map<String, dynamic>> rows)
    : this._(_OpeningDialogActionKind.bulkDelete, rows: rows);
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle.trim().isNotEmpty;
    final hasTitle = title.trim().isNotEmpty;
    return Container(
      decoration: _glassCardDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTitle)
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B2B2B),
              ),
            ),
          if (hasSubtitle) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xCC0B2B2B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (hasTitle || hasSubtitle) const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TextFieldBox extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final double width;
  final ValueChanged<String>? onChanged;

  const _TextFieldBox({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.width = 240,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0B2B2B),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.64),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF0B72FF),
                  width: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthDropdownField extends StatelessWidget {
  final DateTime value;
  final double width;
  final ValueChanged<DateTime> onChanged;

  const _MonthDropdownField({
    required this.value,
    required this.onChanged,
    this.width = 220,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final selectedDate = await _showMonthPickerDialog(
            context,
            initialDate: value,
          );
          if (selectedDate == null) return;
          final nextValue = DateTime(selectedDate.year, selectedDate.month, 1);
          if (nextValue == DateTime(value.year, value.month, 1)) return;
          onChanged(nextValue);
        },
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF123E44),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2B727A)),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                offset: const Offset(0, 4),
                color: Colors.black.withValues(alpha: 0.10),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.event_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_monthNameEs(value.month)} ${value.year}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<DateTime?> _showMonthPickerDialog(
  BuildContext context, {
  required DateTime initialDate,
}) {
  return showDatePicker(
    context: context,
    initialDate: DateTime(initialDate.year, initialDate.month, 1),
    firstDate: DateTime(2020, 1, 1),
    lastDate: DateTime(DateTime.now().year + 2, 12, 31),
    helpText: 'Selecciona mes y año del corte',
    fieldLabelText: 'Mes de corte',
    initialEntryMode: DatePickerEntryMode.calendarOnly,
  );
}

class _DateRangeField extends StatelessWidget {
  final DateTime from;
  final DateTime to;
  final double width;
  final VoidCallback onTap;

  const _DateRangeField({
    required this.from,
    required this.to,
    required this.onTap,
    this.width = 250,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF123E44),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2B727A)),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                offset: const Offset(0, 4),
                color: Colors.black.withValues(alpha: 0.10),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.date_range_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_formatDate(from)} - ${_formatDate(to)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? caption;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return OperationalMetricCard(
      icon: icon,
      label: label,
      value: value,
      subtitle: caption,
      width: 220,
      height: caption == null ? 64 : 70,
      margin: EdgeInsets.zero,
    );
  }
}

class _InventorySummaryTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _InventorySummaryTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyState(
        message: 'Sin datos en el resumen de inventario',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingRowHeight: 42,
            dataRowMinHeight: 42,
            dataRowMaxHeight: 56,
            columnSpacing: 28,
            columns: const [
              DataColumn(label: Text('Material')),
              DataColumn(label: Text('Apertura kg')),
              DataColumn(label: Text('Mov. neto kg')),
              DataColumn(label: Text('Prod. entrada kg')),
              DataColumn(label: Text('Prod. salida kg')),
              DataColumn(label: Text('Existencia kg')),
            ],
            rows: rows
                .map(
                  (r) => DataRow(
                    cells: [
                      DataCell(Text(_materialLabel(r['material']?.toString()))),
                      DataCell(Text(_formatKg(_num(r['opening_kg'])))),
                      DataCell(Text(_formatKg(_num(r['net_movement_kg'])))),
                      DataCell(Text(_formatKg(_num(r['prod_in_kg'])))),
                      DataCell(Text(_formatKg(_num(r['prod_out_kg'])))),
                      DataCell(
                        Text(
                          _formatKg(_num(r['on_hand_kg'])),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: (_num(r['on_hand_kg']) ?? 0) < 0
                                ? Colors.red.shade800
                                : const Color(0xFF0B2B2B),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

const double _kOpeningTableMaterialColW = 220;
const double _kOpeningTableCommercialColW = 220;
const double _kOpeningTableKgColW = 120;
const double _kOpeningTableSourceColW = 120;
const double _kOpeningTableLockedColW = 110;
const double _kOpeningTableActionsColW = 78;
const double _kOpeningTableRowHorizontalPadding = 24;
const double _kOpeningTableOuterHorizontalPadding = 16;
const double _kOpeningTableScrollPaddingTop = 8;
const double _kOpeningTableHeaderGap = 8;
const double _kOpeningTableMetaRowGap = 6;
const double _kOpeningTableInsertRowHeight = 54;
const double _kOpeningTableRowGap = 6;
const double _kOpeningTableRowVisualHeight = 56;
const double _kOpeningTableWidthSlack = 12;
const double _kOpeningTableContentW =
    _kOpeningTableMaterialColW +
    _kOpeningTableCommercialColW +
    _kOpeningTableKgColW +
    _kOpeningTableSourceColW +
    _kOpeningTableLockedColW +
    _kOpeningTableActionsColW +
    10 +
    _kOpeningTableRowHorizontalPadding +
    _kOpeningTableOuterHorizontalPadding +
    _kOpeningTableWidthSlack;
const double _kOpeningTableHeaderHeight = 54;
const Color _kFilterAccent = Color(0xFF5A9C9A);
const Color _kFilterAccentSoft = Color(0xFFD6E6E6);
const double _kOpeningTableRowExtent =
    _kOpeningTableRowVisualHeight + _kOpeningTableRowGap;

class _OpeningBalancesTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String? emptyMessage;
  final Widget? insertRow;
  final Widget? headerFiltersRow;
  final bool Function(String columnId)? hasActiveHeaderFilter;
  final void Function(String columnId, String label)? onOpenHeaderFilter;
  final Map<String, String> commercialLabelsByCode;
  final GlobalKey<_OpeningBalancesDataRowState> Function(String rowId)
  rowKeyFor;
  final bool editable;
  final Set<String> selectedIds;
  final int activeRowIndex;
  final int activeColumnIndex;
  final ScrollController? verticalScrollController;
  final ScrollController? horizontalScrollController;
  final void Function(int rowIndex)? onRowTap;
  final void Function(int rowIndex, TapDownDetails details)?
  onRowSecondaryTapDown;
  final void Function(int rowIndex, int colIndex)? onCellTap;
  final void Function(int rowIndex)? onEditableKgCellDoubleTap;
  final void Function(int rowIndex)? onSetActiveRowPreserveSelection;
  final VoidCallback? onInlineCancelSelection;
  final Future<void> Function(
    Map<String, dynamic> row,
    Map<String, dynamic> payload,
  )?
  onInlineSaveRow;
  final Future<void> Function(Map<String, dynamic> row)? onEditRow;
  final Future<void> Function(Map<String, dynamic> row)? onDeleteRow;

  const _OpeningBalancesTable({
    required this.rows,
    this.emptyMessage,
    this.insertRow,
    this.headerFiltersRow,
    this.hasActiveHeaderFilter,
    this.onOpenHeaderFilter,
    required this.commercialLabelsByCode,
    required this.rowKeyFor,
    this.editable = false,
    this.selectedIds = const <String>{},
    this.activeRowIndex = 0,
    this.activeColumnIndex = 0,
    this.verticalScrollController,
    this.horizontalScrollController,
    this.onRowTap,
    this.onRowSecondaryTapDown,
    this.onCellTap,
    this.onEditableKgCellDoubleTap,
    this.onSetActiveRowPreserveSelection,
    this.onInlineCancelSelection,
    this.onInlineSaveRow,
    this.onEditRow,
    this.onDeleteRow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth > _kOpeningTableContentW
              ? constraints.maxWidth
              : _kOpeningTableContentW;
          return Scrollbar(
            controller: horizontalScrollController,
            thumbVisibility: true,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Scrollbar(
                  controller: verticalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: verticalScrollController,
                    padding: const EdgeInsets.fromLTRB(
                      8,
                      _kOpeningTableScrollPaddingTop,
                      8,
                      10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _OpeningBalancesHeaderRow(
                          hasActiveFilter: hasActiveHeaderFilter,
                          onOpenFilter: onOpenHeaderFilter,
                        ),
                        if (headerFiltersRow != null) ...[
                          const SizedBox(height: 6),
                          headerFiltersRow!,
                        ],
                        if (insertRow != null) ...[
                          const SizedBox(height: 6),
                          insertRow!,
                        ],
                        const SizedBox(height: _kOpeningTableHeaderGap),
                        if (rows.isEmpty)
                          _EmptyState(
                            message:
                                emptyMessage ??
                                'Sin opening_balances para este mes/sitio.',
                          )
                        else
                          for (var i = 0; i < rows.length; i++) ...[
                            _OpeningBalancesDataRow(
                              key: rowKeyFor((rows[i]['id'] ?? '').toString()),
                              row: rows[i],
                              commercialLabelsByCode: commercialLabelsByCode,
                              rowIndex: i,
                              editable: editable,
                              isSelected: selectedIds.contains(
                                (rows[i]['id'] ?? '').toString(),
                              ),
                              isActiveRow: i == activeRowIndex,
                              activeColumnIndex: activeColumnIndex,
                              onRowTap: onRowTap == null
                                  ? null
                                  : () => onRowTap!(i),
                              onRowSecondaryTapDown:
                                  onRowSecondaryTapDown == null
                                  ? null
                                  : (details) =>
                                        onRowSecondaryTapDown!(i, details),
                              onCellTap: onCellTap == null
                                  ? null
                                  : (col) => onCellTap!(i, col),
                              onEditableKgCellDoubleTap:
                                  onEditableKgCellDoubleTap == null
                                  ? null
                                  : () => onEditableKgCellDoubleTap!(i),
                              onInlineCancelSelection: onInlineCancelSelection,
                              onInlineNavigateRowDelta: (delta) {
                                if (selectedIds.length <= 1 ||
                                    onSetActiveRowPreserveSelection == null) {
                                  return;
                                }
                                final candidate = (i + delta).clamp(
                                  0,
                                  rows.length - 1,
                                );
                                final candidateId =
                                    (rows[candidate]['id'] ?? '').toString();
                                if (!selectedIds.contains(candidateId)) return;
                                onSetActiveRowPreserveSelection!(candidate);
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  final s = rowKeyFor(candidateId).currentState;
                                  s?.startInlineEdit(requestFocus: false);
                                  s?.focusInlineKgField();
                                });
                              },
                              onInlineSaveRow: onInlineSaveRow,
                              onEditRow: onEditRow,
                              onDeleteRow: onDeleteRow,
                            ),
                            if (i != rows.length - 1)
                              const SizedBox(height: _kOpeningTableRowGap),
                          ],
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
  }
}

class _OpeningBalancesHeaderRow extends StatelessWidget {
  final bool Function(String columnId)? hasActiveFilter;
  final void Function(String columnId, String label)? onOpenFilter;

  const _OpeningBalancesHeaderRow({this.hasActiveFilter, this.onOpenFilter});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: Color(0xFF0B2B2B),
    );
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.black.withValues(alpha: 0.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        height: _kOpeningTableHeaderHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _OpeningHeaderCell(
                label: 'MATERIAL',
                columnId: 'material',
                width: _kOpeningTableMaterialColW,
                style: textStyle,
                active: hasActiveFilter?.call('material') ?? false,
                onFilter: onOpenFilter == null
                    ? null
                    : () => onOpenFilter!('material', 'MATERIAL'),
              ),
              _OpeningHeaderCell(
                label: 'MATERIAL COMERCIAL',
                columnId: 'commercial',
                width: _kOpeningTableCommercialColW,
                style: textStyle,
                active: hasActiveFilter?.call('commercial') ?? false,
                onFilter: onOpenFilter == null
                    ? null
                    : () => onOpenFilter!('commercial', 'MATERIAL COMERCIAL'),
              ),
              _OpeningHeaderCell(
                label: 'APERTURA KG',
                columnId: 'kg',
                width: _kOpeningTableKgColW,
                style: textStyle,
                active: hasActiveFilter?.call('kg') ?? false,
                onFilter: onOpenFilter == null
                    ? null
                    : () => onOpenFilter!('kg', 'APERTURA KG'),
              ),
              _OpeningHeaderCell(
                label: 'ORIGEN',
                columnId: 'source',
                width: _kOpeningTableSourceColW,
                style: textStyle,
                active: hasActiveFilter?.call('source') ?? false,
                onFilter: onOpenFilter == null
                    ? null
                    : () => onOpenFilter!('source', 'ORIGEN'),
              ),
              _OpeningHeaderCell(
                label: 'BLOQUEADO',
                columnId: 'locked',
                width: _kOpeningTableLockedColW,
                style: textStyle,
              ),
              SizedBox(width: 10),
              _OpeningHeaderCell(
                label: 'ACCIONES',
                columnId: 'actions',
                width: _kOpeningTableActionsColW,
                style: textStyle,
                alignEnd: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpeningHeaderCell extends StatelessWidget {
  final String label;
  final String columnId;
  final double width;
  final TextStyle style;
  final bool alignEnd;
  final bool active;
  final VoidCallback? onFilter;

  const _OpeningHeaderCell({
    required this.label,
    required this.columnId,
    required this.width,
    required this.style,
    this.alignEnd = false,
    this.active = false,
    this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: alignEnd
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (onFilter != null) ...[
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onFilter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: active
                      ? _kFilterAccent
                      : _kFilterAccentSoft.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active
                        ? _kFilterAccent.withValues(alpha: 0.55)
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
          ],
          Expanded(
            child: Text(
              label,
              style: style,
              overflow: TextOverflow.ellipsis,
              textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpeningBalancesDataRow extends StatefulWidget {
  final Map<String, dynamic> row;
  final Map<String, String> commercialLabelsByCode;
  final int rowIndex;
  final bool editable;
  final bool isSelected;
  final bool isActiveRow;
  final int activeColumnIndex;
  final VoidCallback? onRowTap;
  final ValueChanged<TapDownDetails>? onRowSecondaryTapDown;
  final ValueChanged<int>? onCellTap;
  final VoidCallback? onEditableKgCellDoubleTap;
  final VoidCallback? onInlineCancelSelection;
  final ValueChanged<int>? onInlineNavigateRowDelta;
  final Future<void> Function(
    Map<String, dynamic> row,
    Map<String, dynamic> payload,
  )?
  onInlineSaveRow;
  final Future<void> Function(Map<String, dynamic> row)? onEditRow;
  final Future<void> Function(Map<String, dynamic> row)? onDeleteRow;

  const _OpeningBalancesDataRow({
    super.key,
    required this.row,
    required this.commercialLabelsByCode,
    required this.rowIndex,
    required this.editable,
    required this.isSelected,
    required this.isActiveRow,
    required this.activeColumnIndex,
    this.onRowTap,
    this.onRowSecondaryTapDown,
    this.onCellTap,
    this.onEditableKgCellDoubleTap,
    this.onInlineCancelSelection,
    this.onInlineNavigateRowDelta,
    this.onInlineSaveRow,
    this.onEditRow,
    this.onDeleteRow,
  });

  @override
  State<_OpeningBalancesDataRow> createState() =>
      _OpeningBalancesDataRowState();
}

class _OpeningBalancesDataRowState extends State<_OpeningBalancesDataRow> {
  bool _hovering = false;
  bool _editing = false;
  late final TextEditingController _weightC;
  final FocusNode _weightFocusNode = FocusNode(debugLabel: 'open_weight');

  bool get isInlineEditing => _editing;

  @override
  void initState() {
    super.initState();
    _weightC = TextEditingController();
  }

  @override
  void dispose() {
    _weightC.dispose();
    _weightFocusNode.dispose();
    super.dispose();
  }

  void startInlineEdit({bool requestFocus = true}) {
    if (!widget.editable) return;
    final weight = _num(widget.row['weight_kg']);
    _weightC.text = weight == null ? '' : weight.toStringAsFixed(2);
    setState(() {
      _editing = true;
    });
    if (requestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _weightFocusNode.requestFocus();
        _weightC.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _weightC.text.length,
        );
      });
    }
  }

  void focusInlineKgField() {
    if (!_editing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_weightFocusNode);
      _weightC.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _weightC.text.length,
      );
    });
  }

  void _enterEditingFromPointer() {
    if (!widget.editable) return;
    widget.onRowTap?.call();
    widget.onCellTap?.call(2);
    if (!_editing) {
      final weight = _num(widget.row['weight_kg']);
      _weightC.text = weight == null ? '' : weight.toStringAsFixed(2);
      setState(() => _editing = true);
    }
    focusInlineKgField();
  }

  void cancelInlineEdit() {
    if (!_editing) return;
    setState(() => _editing = false);
  }

  void moveInlineEditCell(int delta) {
    // Single editable cell (KG). Keep method for keyboard contract callers.
  }

  void submitInlineEdit() {
    if (!_editing || widget.onInlineSaveRow == null) return;
    widget.onInlineSaveRow!(widget.row, <String, dynamic>{
      'weight_kg': _parseDouble(_weightC.text),
    });
  }

  KeyEventResult _handleInlineFieldKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      widget.onInlineCancelSelection?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      widget.onInlineNavigateRowDelta?.call(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      widget.onInlineNavigateRowDelta?.call(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      submitInlineEdit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final highlighted = widget.isSelected || _hovering;
    final rowBg = widget.isSelected
        ? const Color(
            0xFF00A3FF,
          ).withValues(alpha: widget.isActiveRow ? 0.16 : 0.12)
        : _hovering
        ? const Color(0xFFE9F7EE)
        : Colors.white;

    Widget frameCell(int col, Widget child) {
      final isActiveCell = _editing
          ? (col == 2)
          : (widget.isActiveRow &&
                widget.activeColumnIndex >= 0 &&
                widget.activeColumnIndex == col);
      if (!isActiveCell) return child;
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF0B72FF).withValues(alpha: 0.85),
            width: 1.15,
          ),
        ),
        child: child,
      );
    }

    Widget tappableCell({
      required int col,
      required double width,
      required Widget child,
      bool alignEnd = false,
      bool editableHover = false,
      VoidCallback? onDoubleTap,
    }) {
      return frameCell(
        col,
        SizedBox(
          width: width,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            hoverColor: editableHover
                ? const Color(0xFF0B72FF).withValues(alpha: 0.08)
                : Colors.transparent,
            splashColor: editableHover
                ? const Color(0xFF0B72FF).withValues(alpha: 0.10)
                : Colors.transparent,
            highlightColor: editableHover
                ? const Color(0xFF0B72FF).withValues(alpha: 0.06)
                : Colors.transparent,
            onTap: widget.onCellTap == null
                ? null
                : () => widget.onCellTap!(col),
            onDoubleTap: onDoubleTap,
            child: Align(
              alignment: alignEnd
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    final commercialCode = (row['commercial_material_code'] ?? '')
        .toString()
        .trim();
    final sourceUiLabel = _openingSourceUiLabel(row);
    final isGeneratedTotalRow =
        sourceUiLabel == 'Total generado' && commercialCode.isEmpty;
    final commercialLabel = commercialCode.isEmpty
        ? (isGeneratedTotalRow ? 'Total sin distribuir' : '—')
        : (widget.commercialLabelsByCode[commercialCode] ?? commercialCode);
    final locked = row['locked_at'] != null;

    return TapRegion(
      onTapOutside: (_) {
        if (_editing) {
          widget.onInlineCancelSelection?.call();
        }
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (_) {
            if (_editing) return;
            widget.onRowTap?.call();
          },
          onSecondaryTapDown: widget.onRowSecondaryTapDown,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, highlighted ? -1.5 : 0, 0),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: highlighted ? 3 : 0.4,
              color: rowBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: widget.isSelected
                      ? const Color(0xFF00A3FF).withValues(alpha: 0.60)
                      : Colors.white.withValues(alpha: 0.0),
                ),
              ),
              child: SizedBox(
                height: _kOpeningTableRowVisualHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      tappableCell(
                        col: 0,
                        width: _kOpeningTableMaterialColW,
                        child: Text(
                          _materialLabel(row['material']?.toString()),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0B2B2B),
                          ),
                        ),
                      ),
                      tappableCell(
                        col: 1,
                        width: _kOpeningTableCommercialColW,
                        child: Text(
                          commercialLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: commercialCode.isEmpty
                                ? (isGeneratedTotalRow
                                      ? const Color(0xFF8A5B12)
                                      : const Color(0xFF567070))
                                : const Color(0xFF0B2B2B),
                          ),
                        ),
                      ),
                      tappableCell(
                        col: 2,
                        width: _kOpeningTableKgColW,
                        editableHover: widget.editable && !_editing,
                        onDoubleTap: widget.editable && !_editing
                            ? _enterEditingFromPointer
                            : null,
                        child: _editing
                            ? Focus(
                                onKeyEvent: (_, event) =>
                                    _handleInlineFieldKey(event),
                                child: TextField(
                                  controller: _weightC,
                                  focusNode: _weightFocusNode,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: _openingInlineFieldDecoration(
                                    hintText: '0',
                                  ),
                                  onTap: focusInlineKgField,
                                  onTapOutside: (event) {
                                    final isSecondaryMouseClick =
                                        event.kind == PointerDeviceKind.mouse &&
                                        (event.buttons &
                                                kSecondaryMouseButton) !=
                                            0;
                                    if (isSecondaryMouseClick) return;
                                    widget.onInlineCancelSelection?.call();
                                  },
                                  onSubmitted: (_) => submitInlineEdit(),
                                ),
                              )
                            : Listener(
                                behavior: HitTestBehavior.opaque,
                                onPointerDown: (_) {
                                  if (!widget.editable) return;
                                  widget.onRowTap?.call();
                                  widget.onCellTap?.call(2);
                                },
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: widget.editable
                                      ? _enterEditingFromPointer
                                      : null,
                                  child: Text(
                                    _formatKg(_num(row['weight_kg'])),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0B2B2B),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      tappableCell(
                        col: 3,
                        width: _kOpeningTableSourceColW,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: switch (sourceUiLabel) {
                              'Plantilla' => const Color(
                                0xFF6BA8FF,
                              ).withValues(alpha: 0.14),
                              'Total generado' => const Color(
                                0xFFE7B75C,
                              ).withValues(alpha: 0.18),
                              'Manual' => const Color(
                                0xFF3FAE9A,
                              ).withValues(alpha: 0.14),
                              _ => Colors.white.withValues(alpha: 0.30),
                            },
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: switch (sourceUiLabel) {
                                'Plantilla' => const Color(
                                  0xFF6BA8FF,
                                ).withValues(alpha: 0.35),
                                'Total generado' => const Color(
                                  0xFFE7B75C,
                                ).withValues(alpha: 0.45),
                                'Manual' => const Color(
                                  0xFF3FAE9A,
                                ).withValues(alpha: 0.35),
                                _ => Colors.white.withValues(alpha: 0.38),
                              },
                            ),
                          ),
                          child: Text(
                            sourceUiLabel,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: switch (sourceUiLabel) {
                                'Plantilla' => const Color(0xFF295FA9),
                                'Total generado' => const Color(0xFF7E5610),
                                'Manual' => const Color(0xFF14685E),
                                _ => const Color(0xFF0B2B2B),
                              },
                            ),
                          ),
                        ),
                      ),
                      tappableCell(
                        col: 4,
                        width: _kOpeningTableLockedColW,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              locked
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              size: 14,
                              color: locked
                                  ? Colors.red.shade700
                                  : const Color(0xFF2A4B49),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              locked ? 'Sí' : 'No',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: locked
                                    ? Colors.red.shade700
                                    : const Color(0xFF0B2B2B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      tappableCell(
                        col: 5,
                        width: _kOpeningTableActionsColW,
                        alignEnd: true,
                        child: widget.editable
                            ? PopupMenuButton<String>(
                                tooltip: 'Acciones',
                                padding: EdgeInsets.zero,
                                color: const Color(0xE6F2F7F6),
                                onSelected: (value) {
                                  switch (value) {
                                    case 'edit':
                                      widget.onEditRow?.call(row);
                                      break;
                                    case 'save':
                                      submitInlineEdit();
                                      break;
                                    case 'cancel':
                                      cancelInlineEdit();
                                      break;
                                    case 'delete':
                                      widget.onDeleteRow?.call(row);
                                      break;
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (_editing) ...const [
                                    PopupMenuItem<String>(
                                      value: 'save',
                                      child: Text('GUARDAR'),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'cancel',
                                      child: Text('CANCELAR'),
                                    ),
                                    PopupMenuDivider(),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text('ELIMINAR'),
                                    ),
                                  ] else ...const [
                                    PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Text('EDITAR'),
                                    ),
                                    PopupMenuDivider(),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text('ELIMINAR'),
                                    ),
                                  ],
                                ],
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.40),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.58,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.more_horiz,
                                    size: 18,
                                    color: Color(0xFF0B2B2B),
                                  ),
                                ),
                              )
                            : const Text(
                                '—',
                                style: TextStyle(
                                  color: Color(0x88294545),
                                  fontWeight: FontWeight.w700,
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
  }
}

InputDecoration _openingInlineFieldDecoration({String? hintText}) {
  return InputDecoration(
    isDense: true,
    hintText: hintText,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.70),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: const Color(0xFF0B72FF).withValues(alpha: 0.75),
        width: 1.1,
      ),
    ),
  );
}

String _openingSourceUiLabel(Map<String, dynamic> row) {
  final raw = (row['source'] ?? '').toString().trim();
  final normalized = raw.toUpperCase();
  switch (normalized) {
    case 'GENERATED_TOTAL':
      return 'Total generado';
    case 'TEMPLATE_SEED':
      return 'Plantilla';
    case 'MANUAL':
      return 'Manual';
    case '':
      return '—';
    default:
      return raw;
  }
}

InputDecoration _openingFilterSearchDecoration({String? hintText}) {
  return InputDecoration(
    isDense: true,
    hintText: hintText,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    filled: true,
    fillColor: const Color(0xFFDDE7EC).withValues(alpha: 0.85),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: const Color(0xFF2EA8FF).withValues(alpha: 0.9),
        width: 1.2,
      ),
    ),
  );
}

class _PreviousMonthNegativeWarning extends StatelessWidget {
  final List<Map<String, dynamic>> rows;

  const _PreviousMonthNegativeWarning({required this.rows});

  @override
  Widget build(BuildContext context) {
    final orderedRows = [...rows]
      ..sort((a, b) {
        final aw = _num(a['on_hand_kg']) ?? 0;
        final bw = _num(b['on_hand_kg']) ?? 0;
        return aw.compareTo(bw);
      });
    final chips = orderedRows.take(6).map((row) {
      final material = (row['material'] ?? '').toString().trim();
      final onHand = _num(row['on_hand_kg']) ?? 0;
      return '${_materialLabel(material)} (${_formatKg(onHand)})';
    }).toList();
    final hasMore = orderedRows.length > chips.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFB74D).withValues(alpha: 0.75),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No puedes generar este corte: el cierre del mes anterior tiene inventario negativo.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A4B00),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            chips.join(' • ') + (hasMore ? ' • ...' : ''),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8A4B00),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CutOpeningReportsTabs extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> suggestedClosingRows;
  final List<_CommercialMaterialOption> commercialMaterials;

  const _CutOpeningReportsTabs({
    required this.rows,
    required this.suggestedClosingRows,
    required this.commercialMaterials,
  });

  @override
  Widget build(BuildContext context) {
    final commercialByCode = <String, _CommercialMaterialOption>{
      for (final c in commercialMaterials) c.code: c,
    };

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
              ),
              child: TabBar(
                isScrollable: true,
                dividerColor: Colors.transparent,
                indicatorPadding: const EdgeInsets.all(4),
                indicator: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: const Color(0xFF0B2B2B),
                unselectedLabelColor: const Color(0xCC0B2B2B),
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                tabs: const [
                  Tab(text: 'Ajuste vs cierre'),
                  Tab(text: 'Material operativo'),
                  Tab(text: 'Material comercial'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 320,
            child: TabBarView(
              children: [
                _CutAdjustmentTable(
                  rows: _aggregateOpeningAdjustmentVsSuggested(
                    rows,
                    suggestedClosingRows,
                  ),
                ),
                _CutReportTable(
                  labelHeader: 'Material operativo',
                  rows: _aggregateOpeningByOperational(rows),
                ),
                _CutReportTable(
                  labelHeader: 'Material comercial',
                  rows: _aggregateOpeningByCommercial(rows, commercialByCode),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CutAdjustmentRow {
  final String material;
  final String label;
  final double suggestedClosingKg;
  final double openingActualKg;
  final double adjustmentKg;

  const _CutAdjustmentRow({
    required this.material,
    required this.label,
    required this.suggestedClosingKg,
    required this.openingActualKg,
    required this.adjustmentKg,
  });
}

class _CutAdjustmentTable extends StatelessWidget {
  final List<_CutAdjustmentRow> rows;

  const _CutAdjustmentTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final sorted = [...rows]
      ..sort((a, b) {
        final byOrder = _inventorySummaryMaterialOrder(
          a.material,
        ).compareTo(_inventorySummaryMaterialOrder(b.material));
        if (byOrder != 0) return byOrder;
        return _normalizeSortKey(a.label).compareTo(_normalizeSortKey(b.label));
      });
    final totalAdjustment = sorted.fold<double>(
      0,
      (sum, r) => sum + r.adjustmentKg,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Text(
                  '${sorted.length} materiales',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kOperationalMetricMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  'Ajuste neto: ${_formatSignedKg(totalAdjustment)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: totalAdjustment == 0
                        ? const Color(0xFF0B2B2B)
                        : (totalAdjustment > 0
                              ? const Color(0xFF0B5C50)
                              : Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowHeight: 42,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 54,
                      columnSpacing: 18,
                      columns: const [
                        DataColumn(label: Text('Material operativo')),
                        DataColumn(label: Text('Cierre sugerido kg')),
                        DataColumn(label: Text('Apertura actual kg')),
                        DataColumn(label: Text('Ajuste kg')),
                      ],
                      rows: sorted
                          .map(
                            (r) => DataRow(
                              cells: [
                                DataCell(Text(r.label)),
                                DataCell(Text(_formatKg(r.suggestedClosingKg))),
                                DataCell(
                                  Text(
                                    _formatKg(r.openingActualKg),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _formatSignedKg(r.adjustmentKg),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: r.adjustmentKg == 0
                                          ? const Color(0xFF0B2B2B)
                                          : (r.adjustmentKg > 0
                                                ? const Color(0xFF0B5C50)
                                                : Colors.red.shade700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CutReportTable extends StatelessWidget {
  final String labelHeader;
  final List<_CutReportRow> rows;

  const _CutReportTable({required this.labelHeader, required this.rows});

  @override
  Widget build(BuildContext context) {
    final sorted = [...rows]
      ..sort((a, b) {
        final byLabel = _normalizeSortKey(
          a.label,
        ).compareTo(_normalizeSortKey(b.label));
        if (byLabel != 0) return byLabel;
        return a.key.compareTo(b.key);
      });
    final totalKg = sorted.fold<double>(0, (sum, r) => sum + r.weightKg);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Text(
                  '${sorted.length} renglones',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kOperationalMetricMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  'Total: ${_formatKg(totalKg)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0B2B2B),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowHeight: 42,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 52,
                      columnSpacing: 20,
                      columns: [
                        DataColumn(label: Text(labelHeader)),
                        const DataColumn(label: Text('Renglones')),
                        const DataColumn(label: Text('Opening kg')),
                      ],
                      rows: sorted
                          .map(
                            (r) => DataRow(
                              cells: [
                                DataCell(Text(r.label)),
                                DataCell(Text('${r.rowCount}')),
                                DataCell(
                                  Text(
                                    _formatKg(r.weightKg),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CutReportRow {
  final String key;
  final String label;
  final int rowCount;
  final double weightKg;

  const _CutReportRow({
    required this.key,
    required this.label,
    required this.rowCount,
    required this.weightKg,
  });
}

List<_CutAdjustmentRow> _aggregateOpeningAdjustmentVsSuggested(
  List<Map<String, dynamic>> openingRows,
  List<Map<String, dynamic>> suggestedClosingRows,
) {
  final openingAgg = _aggregateOpeningByOperational(openingRows);
  final openingByMaterial = <String, double>{
    for (final r in openingAgg) r.key: r.weightKg,
  };
  final suggestedByMaterial = <String, double>{};
  for (final row in suggestedClosingRows) {
    final material = _normalizeOperationalMaterialForReport(
      (row['material'] ?? '').toString(),
    );
    if (material.isEmpty) continue;
    suggestedByMaterial[material] = _num(row['on_hand_kg']) ?? 0;
  }

  final keys = <String>{
    ...openingByMaterial.keys,
    ...suggestedByMaterial.keys,
    ..._kInventorySummaryMaterials.map((m) => m.value),
  };

  return keys.map((material) {
    final suggested = suggestedByMaterial[material] ?? 0;
    final opening = openingByMaterial[material] ?? 0;
    return _CutAdjustmentRow(
      material: material,
      label: _materialLabel(material),
      suggestedClosingKg: suggested,
      openingActualKg: opening,
      adjustmentKg: opening - suggested,
    );
  }).toList();
}

List<_CutReportRow> _aggregateOpeningByOperational(
  List<Map<String, dynamic>> rows,
) {
  final grouped = <String, _MutableCutReport>{};
  for (final row in rows) {
    final raw = (row['material'] ?? '').toString().trim();
    if (raw.isEmpty) continue;
    final material = _normalizeOperationalMaterialForReport(raw);
    final entry = grouped.putIfAbsent(
      material,
      () => _MutableCutReport(key: material, label: _materialLabel(material)),
    );
    entry.rowCount += 1;
    entry.weightKg += _num(row['weight_kg']) ?? 0;
  }
  return grouped.values.map((e) => e.freeze()).toList();
}

List<_CutReportRow> _aggregateOpeningByCommercial(
  List<Map<String, dynamic>> rows,
  Map<String, _CommercialMaterialOption> commercialByCode,
) {
  final grouped = <String, _MutableCutReport>{};
  for (final row in rows) {
    final code = (row['commercial_material_code'] ?? '').toString().trim();
    final key = code.isEmpty ? '__UNCLASSIFIED__' : code;
    final label = code.isEmpty
        ? 'Sin clasificar'
        : (commercialByCode[code]?.name ?? code);
    final entry = grouped.putIfAbsent(
      key,
      () => _MutableCutReport(key: key, label: label),
    );
    entry.rowCount += 1;
    entry.weightKg += _num(row['weight_kg']) ?? 0;
  }
  return grouped.values.map((e) => e.freeze()).toList();
}

String _normalizeOperationalMaterialForReport(String material) {
  switch (material) {
    case 'METAL_ALUMINUM':
    case 'METAL_STEEL':
    case 'METAL_COPPER':
    case 'METAL_BRASS':
    case 'METAL_OTHER':
      return 'METAL';
    default:
      return material;
  }
}

class _MutableCutReport {
  final String key;
  final String label;
  int rowCount = 0;
  double weightKg = 0;

  _MutableCutReport({required this.key, required this.label});

  _CutReportRow freeze() => _CutReportRow(
    key: key,
    label: label,
    rowCount: rowCount,
    weightKg: weightKg,
  );
}

class _OpeningBalanceEditDialog extends StatefulWidget {
  final Map<String, dynamic> row;
  final String materialLabel;
  final List<_CommercialMaterialOption> commercialOptions;

  const _OpeningBalanceEditDialog({
    required this.row,
    required this.materialLabel,
    required this.commercialOptions,
  });

  @override
  State<_OpeningBalanceEditDialog> createState() =>
      _OpeningBalanceEditDialogState();
}

class _OpeningBalanceEditDialogState extends State<_OpeningBalanceEditDialog> {
  late final TextEditingController _weightC;
  late final TextEditingController _notesC;
  final FocusNode _weightFocusNode = FocusNode();
  String? _selectedCommercialCode;
  bool _weightPrimed = false;

  @override
  void initState() {
    super.initState();
    final weight = (_num(widget.row['weight_kg']) ?? 0).toStringAsFixed(2);
    _weightC = TextEditingController(text: weight);
    _notesC = TextEditingController(
      text: (widget.row['notes'] ?? '').toString(),
    );
    final current = (widget.row['commercial_material_code'] ?? '').toString();
    final currentExists = widget.commercialOptions.any(
      (o) => o.code == current,
    );
    _selectedCommercialCode = (current.isEmpty || !currentExists)
        ? null
        : current;
  }

  @override
  void dispose() {
    _weightFocusNode.dispose();
    _weightC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  void _primeWeightFieldSelection() {
    if (_weightPrimed) return;
    _weightPrimed = true;
    _weightC.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _weightC.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> payload() => {
      'commercial_material_code': _selectedCommercialCode,
      'weight_kg': _parseDouble(_weightC.text),
      'notes': _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
    };
    return Focus(
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.pop(context);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          Navigator.pop(context, payload());
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AlertDialog(
        title: const Text('Editar opening balance'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.materialLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Comercial: ${_selectedCommercialCode ?? '-'}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF425A5A)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _selectedCommercialCode,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Material comercial (opcional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sin material comercial'),
                  ),
                  ...widget.commercialOptions.map(
                    (opt) => DropdownMenuItem<String?>(
                      value: opt.code,
                      child: Text(opt.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedCommercialCode = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _weightC,
                focusNode: _weightFocusNode,
                autofocus: true,
                onTap: _primeWeightFieldSelection,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Opening kg',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesC,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText: 'Ajuste manual de corte',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, payload()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _OpeningBalanceCreateDialog extends StatefulWidget {
  final List<_CommercialMaterialOption> allCommercialMaterials;
  final List<_GeneralMaterialOption> generalMaterials;
  final Map<String, Set<String>> commercialSourceRulesByCode;
  final List<Map<String, dynamic>> openingTemplateRows;

  const _OpeningBalanceCreateDialog({
    required this.allCommercialMaterials,
    required this.generalMaterials,
    required this.commercialSourceRulesByCode,
    required this.openingTemplateRows,
  });

  @override
  State<_OpeningBalanceCreateDialog> createState() =>
      _OpeningBalanceCreateDialogState();
}

class _OpeningBalanceCreateDialogState
    extends State<_OpeningBalanceCreateDialog> {
  String _material = _kInventoryMaterials.first.value;
  String? _selectedCommercialCode;
  final TextEditingController _weightC = TextEditingController(text: '0');
  final TextEditingController _notesC = TextEditingController();
  final FocusNode _weightFocusNode = FocusNode();
  bool _weightPrimed = false;

  String _normalizeOpeningKey(String value) => value.trim().toUpperCase();

  List<_CommercialMaterialOption> get _filteredCommercialOptions {
    final templateRows =
        widget.openingTemplateRows.where((r) {
          final material = _normalizeOpeningKey(
            (r['material'] ?? '').toString(),
          );
          final active = r['is_active'] == null
              ? true
              : (r['is_active'] == true);
          return active && material == _normalizeOpeningKey(_material);
        }).toList()..sort((a, b) {
          final ao = (a['sort_order'] as num?)?.toInt() ?? 999999;
          final bo = (b['sort_order'] as num?)?.toInt() ?? 999999;
          final byOrder = ao.compareTo(bo);
          if (byOrder != 0) return byOrder;
          return (a['commercial_material_code'] ?? '').toString().compareTo(
            (b['commercial_material_code'] ?? '').toString(),
          );
        });

    if (templateRows.isNotEmpty) {
      final byCode = <String, _CommercialMaterialOption>{
        for (final c in widget.allCommercialMaterials)
          _normalizeOpeningKey(c.code): c,
      };
      final templated = <_CommercialMaterialOption>[];
      final seen = <String>{};
      for (final row in templateRows) {
        final code = _normalizeOpeningKey(
          (row['commercial_material_code'] ?? '').toString(),
        );
        final option = byCode[code];
        if (option != null && seen.add(code)) templated.add(option);
      }
      final compatible =
          widget.allCommercialMaterials
              .where(
                (c) => _commercialMatchesInventoryMaterial(
                  option: c,
                  selectedMaterial: _material,
                  generalMaterials: widget.generalMaterials,
                  commercialSourceRulesByCode:
                      widget.commercialSourceRulesByCode,
                ),
              )
              .toList()
            ..sort((a, b) {
              final byName = _normalizeSortKey(
                a.name,
              ).compareTo(_normalizeSortKey(b.name));
              if (byName != 0) return byName;
              return a.code.compareTo(b.code);
            });
      for (final option in compatible) {
        final key = _normalizeOpeningKey(option.code);
        if (seen.add(key)) templated.add(option);
      }
      return templated;
    }

    final filtered = widget.allCommercialMaterials
        .where(
          (c) => _commercialMatchesInventoryMaterial(
            option: c,
            selectedMaterial: _material,
            generalMaterials: widget.generalMaterials,
            commercialSourceRulesByCode: widget.commercialSourceRulesByCode,
          ),
        )
        .toList();
    filtered.sort((a, b) {
      final byName = _normalizeSortKey(
        a.name,
      ).compareTo(_normalizeSortKey(b.name));
      if (byName != 0) return byName;
      return a.code.compareTo(b.code);
    });
    return filtered;
  }

  @override
  void dispose() {
    _weightFocusNode.dispose();
    _weightC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  void _primeWeightFieldSelection() {
    if (_weightPrimed) return;
    _weightPrimed = true;
    _weightC.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _weightC.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> payload() => {
      'material': _material,
      'commercial_material_code': _selectedCommercialCode,
      'weight_kg': _parseDouble(_weightC.text),
      'notes': _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
    };
    return Focus(
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.pop(context);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          Navigator.pop(context, payload());
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AlertDialog(
        title: const Text('Nuevo opening balance'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _material,
                decoration: const InputDecoration(labelText: 'Material'),
                items: _kInventoryMaterials
                    .map(
                      (m) => DropdownMenuItem<String>(
                        value: m.value,
                        child: Text(m.label),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _material = v;
                    final exists = _filteredCommercialOptions.any(
                      (opt) => opt.code == _selectedCommercialCode,
                    );
                    if (!exists) _selectedCommercialCode = null;
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _selectedCommercialCode,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Material comercial (opcional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sin material comercial'),
                  ),
                  ..._filteredCommercialOptions.map(
                    (opt) => DropdownMenuItem<String?>(
                      value: opt.code,
                      child: Text(opt.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedCommercialCode = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _weightC,
                focusNode: _weightFocusNode,
                autofocus: true,
                onTap: _primeWeightFieldSelection,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Opening kg',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesC,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText: 'Alta manual',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, payload()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
}

class _OpeningBalanceBulkEditDialog extends StatefulWidget {
  final int rowCount;
  final List<_CommercialMaterialOption> allCommercialMaterials;

  const _OpeningBalanceBulkEditDialog({
    required this.rowCount,
    required this.allCommercialMaterials,
  });

  @override
  State<_OpeningBalanceBulkEditDialog> createState() =>
      _OpeningBalanceBulkEditDialogState();
}

class _OpeningBalanceBulkEditDialogState
    extends State<_OpeningBalanceBulkEditDialog> {
  String _commercialMode = 'keep'; // keep | set | clear
  String? _commercialCode;
  String _notesMode = 'keep'; // keep | set | clear
  final TextEditingController _notesC = TextEditingController();

  @override
  void dispose() {
    _notesC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commercialItems = [...widget.allCommercialMaterials]
      ..sort((a, b) {
        final byName = _normalizeSortKey(
          a.name,
        ).compareTo(_normalizeSortKey(b.name));
        if (byName != 0) return byName;
        return a.code.compareTo(b.code);
      });

    Map<String, dynamic> payload() => {
      'commercial_mode': _commercialMode,
      'commercial_material_code': _commercialCode,
      'notes_mode': _notesMode,
      'notes': _notesC.text.trim(),
    };

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.pop(context);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          Navigator.pop(context, payload());
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AlertDialog(
        title: const Text('Edición múltiple (apertura)'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aplicar cambios a ${widget.rowCount} renglones seleccionados',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A4B49),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _commercialMode,
                decoration: const InputDecoration(
                  labelText: 'Material comercial (acción)',
                ),
                items: const [
                  DropdownMenuItem(value: 'keep', child: Text('Sin cambio')),
                  DropdownMenuItem(
                    value: 'set',
                    child: Text('Asignar material comercial'),
                  ),
                  DropdownMenuItem(
                    value: 'clear',
                    child: Text('Limpiar material comercial'),
                  ),
                ],
                onChanged: (v) => setState(() {
                  _commercialMode = v ?? 'keep';
                  if (_commercialMode != 'set') _commercialCode = null;
                }),
              ),
              if (_commercialMode == 'set') ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: _commercialCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Material comercial',
                  ),
                  items: commercialItems
                      .map(
                        (opt) => DropdownMenuItem<String?>(
                          value: opt.code,
                          child: Text(
                            opt.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _commercialCode = v),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _notesMode,
                decoration: const InputDecoration(labelText: 'Notas (acción)'),
                items: const [
                  DropdownMenuItem(value: 'keep', child: Text('Sin cambio')),
                  DropdownMenuItem(
                    value: 'set',
                    child: Text('Reemplazar notas'),
                  ),
                  DropdownMenuItem(
                    value: 'clear',
                    child: Text('Limpiar notas'),
                  ),
                ],
                onChanged: (v) => setState(() => _notesMode = v ?? 'keep'),
              ),
              if (_notesMode == 'set') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _notesC,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    hintText: 'Se aplicarán a todos los seleccionados',
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, payload()),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }
}

class _CutStatusBadge extends StatelessWidget {
  final String status;
  final int openingCount;
  final dynamic generatedAt;
  final dynamic lockedAt;

  const _CutStatusBadge({
    required this.status,
    required this.openingCount,
    required this.generatedAt,
    required this.lockedAt,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = _normalizeMonthlyCutStatus(status);
    final isLocked = _isMonthlyCutLockedStatus(normalizedStatus);
    final label = normalizedStatus == 'cerrado'
        ? 'Cerrado'
        : (normalizedStatus == 'en_revision' ? 'En revision' : 'Abierto');
    final subtitle = '$label · $openingCount renglones';
    return Tooltip(
      message:
          'Estado: $label'
          '${generatedAt != null ? '\nGenerado: ${_formatDateFromAny(generatedAt)}' : ''}'
          '${lockedAt != null ? '\nBloqueado: ${_formatDateFromAny(lockedAt)}' : ''}',
      child: SizedBox(
        width: 220,
        child: OperationalMetricCard(
          icon: isLocked ? Icons.lock_rounded : Icons.edit_note_rounded,
          label: 'Estado corte',
          value: label,
          subtitle: subtitle,
          width: 220,
          height: 70,
          margin: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF0B2B2B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MaterialOption {
  final String value;
  final String label;
  const _MaterialOption(this.value, this.label);
}

class _CommercialMaterialOption {
  final String code;
  final String name;
  final String? inventoryMaterial;
  final String? materialId;

  const _CommercialMaterialOption({
    required this.code,
    required this.name,
    required this.inventoryMaterial,
    required this.materialId,
  });
}

class _GeneralMaterialOption {
  final String id;
  final String name;
  final String? inventoryMaterialCode;

  const _GeneralMaterialOption({
    required this.id,
    required this.name,
    required this.inventoryMaterialCode,
  });
}

String _normalizeInventoryMaterialKey(String value) =>
    value.trim().toUpperCase();

bool _isInventoryMetalMaterial(String material) {
  switch (_normalizeInventoryMaterialKey(material)) {
    case 'METAL':
    case 'METAL_ALUMINUM':
    case 'METAL_STEEL':
    case 'METAL_COPPER':
    case 'METAL_BRASS':
    case 'METAL_OTHER':
      return true;
    default:
      return false;
  }
}

bool _commercialMatchesInventoryMaterial({
  required _CommercialMaterialOption option,
  required String selectedMaterial,
  required List<_GeneralMaterialOption> generalMaterials,
  required Map<String, Set<String>> commercialSourceRulesByCode,
}) {
  final selectedKey = _normalizeInventoryMaterialKey(selectedMaterial);
  if (selectedKey.isEmpty) return false;

  final optionCodeKey = _normalizeInventoryMaterialKey(option.code);
  final directInventoryKey = _normalizeInventoryMaterialKey(
    option.inventoryMaterial ?? '',
  );
  final sourceRules = commercialSourceRulesByCode[optionCodeKey];
  if (sourceRules != null && sourceRules.isNotEmpty) {
    if (sourceRules.contains(selectedKey)) return true;
    if (_isInventoryMetalMaterial(selectedKey) &&
        sourceRules.any(_isInventoryMetalMaterial)) {
      return true;
    }
    if (directInventoryKey.isNotEmpty && directInventoryKey == selectedKey) {
      return true;
    }
    return false;
  }

  var optionMaterialKey = directInventoryKey;
  final optionMaterialId = (option.materialId ?? '').trim();
  if (optionMaterialId.isNotEmpty) {
    final general = generalMaterials.firstWhere(
      (g) => g.id == optionMaterialId,
      orElse: () => const _GeneralMaterialOption(
        id: '',
        name: '',
        inventoryMaterialCode: null,
      ),
    );
    final generalInventoryKey = _normalizeInventoryMaterialKey(
      general.inventoryMaterialCode ?? '',
    );
    if (generalInventoryKey.isNotEmpty) {
      optionMaterialKey = generalInventoryKey;
    }
  }

  if (optionMaterialKey.isEmpty) return false;
  if (_isInventoryMetalMaterial(selectedKey) &&
      _isInventoryMetalMaterial(optionMaterialKey)) {
    return true;
  }
  return optionMaterialKey == selectedKey;
}

BoxDecoration _glassCardDecoration() {
  return BoxDecoration(
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
  );
}

String _normalizeSortKey(String raw) {
  return raw
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('Ü', 'U')
      .replaceAll('Ñ', 'N')
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .toUpperCase()
      .trim();
}

String _formatDate(DateTime date) {
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  return '$dd/$mm/${date.year}';
}

String _formatDateFromAny(dynamic value) {
  if (value == null) return '-';
  if (value is DateTime) return _formatDate(value);
  final text = value.toString();
  final parsed = DateTime.tryParse(text);
  if (parsed != null) return _formatDate(parsed);
  if (text.length >= 10) return text.substring(0, 10);
  return text;
}

String _normalizeMonthlyCutStatus([String? rawStatus]) {
  final status = (rawStatus ?? '').trim().toLowerCase();
  switch (status) {
    case '':
    case 'draft':
    case 'open':
    case 'opened':
    case 'abierta':
    case 'abierto':
      return 'abierto';
    case 'review':
    case 'in_review':
    case 'en-revision':
    case 'revision':
    case 'en_revision':
      return 'en_revision';
    case 'locked':
    case 'closed':
    case 'close':
    case 'cierre':
    case 'cerrada':
    case 'cerrado':
      return 'cerrado';
    default:
      return status;
  }
}

bool _isMonthlyCutLockedStatus([String? rawStatus]) {
  return _normalizeMonthlyCutStatus(rawStatus) == 'cerrado';
}

Map<String, dynamic>? _normalizeMonthlyCutRow(Map<String, dynamic>? row) {
  if (row == null) return null;
  return <String, dynamic>{
    ...row,
    'status': _normalizeMonthlyCutStatus(row['status']?.toString()),
  };
}

String _dateSql(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.toIso8601String().split('T').first;
}

double? _parseDouble(String raw) {
  final clean = raw.trim().replaceAll(',', '');
  if (clean.isEmpty) return null;
  return double.tryParse(clean);
}

double? _num(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

double _pickNum(Map<String, dynamic>? row, List<String> candidates) {
  if (row == null) return 0;
  for (final key in candidates) {
    if (row.containsKey(key)) {
      return _num(row[key]) ?? 0;
    }
  }
  return 0;
}

String _formatKg(double? value) {
  final v = value ?? 0;
  return '${v.toStringAsFixed(1)} kg';
}

String _formatSignedKg(double? value) {
  final v = value ?? 0;
  final sign = v > 0 ? '+' : '';
  return '$sign${v.toStringAsFixed(1)} kg';
}

int _inventorySummaryMaterialOrder(String material) {
  final index = _kInventorySummaryMaterials.indexWhere(
    (m) => m.value == material,
  );
  return index >= 0 ? index : 9999;
}

class _DateFilterDialogResult {
  final DateTimeRange? range;
  final bool clear;
  const _DateFilterDialogResult({this.range, this.clear = false});
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

Future<_DateFilterDialogResult?> _showInventoryDateRangeFilterDialog(
  BuildContext context, {
  required String label,
  required DateTimeRange bounds,
  DateTimeRange? initialRange,
}) {
  return showDialog<_DateFilterDialogResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      DateTime displayMonth = DateTime(
        (initialRange?.start ?? DateTime.now()).year,
        (initialRange?.start ?? DateTime.now()).month,
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

      return StatefulBuilder(
        builder: (context, setLocalState) {
          final monthFirst = DateTime(displayMonth.year, displayMonth.month, 1);
          final leading = (monthFirst.weekday + 6) % 7;
          final gridStart = monthFirst.subtract(Duration(days: leading));
          final rangePreviewEnd = end ?? hover;

          _DateFilterDialogResult? buildApplyResult() {
            if (start == null) return null;
            final s = dateOnly(start!);
            final e = dateOnly(end ?? start!);
            final from = s.isBefore(e) ? s : e;
            final to = s.isBefore(e) ? e : s;
            return _DateFilterDialogResult(
              range: DateTimeRange(start: from, end: to),
            );
          }

          bool inPreviewRange(DateTime day) {
            if (start == null || rangePreviewEnd == null) return false;
            final a = dateOnly(start!);
            final b = dateOnly(rangePreviewEnd);
            final from = a.isBefore(b) ? a : b;
            final to = a.isBefore(b) ? b : a;
            final d = dateOnly(day);
            return !d.isBefore(from) && !d.isAfter(to);
          }

          return Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.pop(dialogContext);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                final result = buildApplyResult();
                if (result != null) Navigator.pop(dialogContext, result);
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
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      decoration: _inventoryFilterDialogDecoration(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                          const SizedBox(height: 8),
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
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '${_monthNameEs(monthFirst.month)[0].toUpperCase()}${_monthNameEs(monthFirst.month).substring(1)} ${monthFirst.year}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
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
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Expanded(child: Center(child: Text('L'))),
                              Expanded(child: Center(child: Text('M'))),
                              Expanded(child: Center(child: Text('M'))),
                              Expanded(child: Center(child: Text('J'))),
                              Expanded(child: Center(child: Text('V'))),
                              Expanded(child: Center(child: Text('S'))),
                              Expanded(child: Center(child: Text('D'))),
                            ],
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 250,
                            child: Column(
                              children: List.generate(6, (row) {
                                return Expanded(
                                  child: Row(
                                    children: List.generate(7, (col) {
                                      final day = gridStart.add(
                                        Duration(days: row * 7 + col),
                                      );
                                      final inMonth =
                                          day.month == displayMonth.month;
                                      final allowed = withinBounds(day);
                                      final selectedStart =
                                          start != null &&
                                          isSameDay(day, start!);
                                      final selectedEnd =
                                          end != null && isSameDay(day, end!);
                                      final inRange = inPreviewRange(day);
                                      final active =
                                          selectedStart || selectedEnd;
                                      final bgColor = active
                                          ? const Color(0xFF4F8E8C)
                                          : inRange
                                          ? const Color(
                                              0xFFE2EEEC,
                                            ).withValues(alpha: 0.8)
                                          : Colors.transparent;
                                      final txtColor = active
                                          ? Colors.white
                                          : !allowed
                                          ? Colors.black38
                                          : inMonth
                                          ? const Color(0xFF0B2B2B)
                                          : Colors.black54;

                                      return Expanded(
                                        child: MouseRegion(
                                          onHover: (_) {
                                            if (start != null &&
                                                end == null &&
                                                allowed) {
                                              setLocalState(() => hover = day);
                                            }
                                          },
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: !allowed
                                                ? null
                                                : () {
                                                    setLocalState(() {
                                                      if (start == null ||
                                                          (start != null &&
                                                              end != null)) {
                                                        start = dateOnly(day);
                                                        end = null;
                                                        hover = null;
                                                      } else {
                                                        end = dateOnly(day);
                                                      }
                                                    });
                                                  },
                                            child: Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: bgColor,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: active
                                                      ? const Color(0xFF4F8E8C)
                                                      : inRange
                                                      ? const Color(
                                                          0xFF4F8E8C,
                                                        ).withValues(
                                                          alpha: 0.20,
                                                        )
                                                      : Colors.transparent,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${day.day}',
                                                  style: TextStyle(
                                                    color: txtColor,
                                                    fontWeight: active
                                                        ? FontWeight.w800
                                                        : FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            start == null
                                ? 'Selecciona un rango'
                                : '${_formatDate(start!)} - ${_formatDate(end ?? start!)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2A4B49),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                style: _inventoryFilterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: _inventoryFilterOutlinedButtonStyle(),
                                onPressed: () => Navigator.pop(
                                  dialogContext,
                                  const _DateFilterDialogResult(clear: true),
                                ),
                                child: const Text('Limpiar'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: _inventoryFilterFilledButtonStyle(),
                                onPressed: () {
                                  final result = buildApplyResult();
                                  if (result != null) {
                                    Navigator.pop(dialogContext, result);
                                  }
                                },
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
}

BoxDecoration _inventoryFilterDialogDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.62),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
  );
}

ButtonStyle _inventoryFilterOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF2A4B49),
    side: BorderSide(color: const Color(0xFF2A4B49).withValues(alpha: 0.25)),
    backgroundColor: Colors.white.withValues(alpha: 0.40),
  );
}

ButtonStyle _inventoryFilterFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF4F8E8C),
    foregroundColor: Colors.white,
  );
}

ButtonStyle _inventoryActionOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF0B2B2B),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.52)),
    backgroundColor: Colors.white.withValues(alpha: 0.18),
    textStyle: const TextStyle(fontWeight: FontWeight.w700),
  );
}

ButtonStyle _cutFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF4F8E8C),
    foregroundColor: Colors.white,
  );
}

ButtonStyle _cutOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF0B2B2B),
    side: BorderSide(color: const Color(0xFF4F8E8C).withValues(alpha: 0.45)),
    backgroundColor: Colors.white.withValues(alpha: 0.22),
  );
}

String _materialLabel(String? material) {
  if (material == null || material.isEmpty) return '-';
  if (material == 'METAL') return 'Metal';
  if (material == 'PAPEL_REVUELTO' || material == 'REVUELTO') return 'Papel';
  for (final m in _kInventoryMaterials) {
    if (m.value == material) return m.label;
  }
  return material;
}
