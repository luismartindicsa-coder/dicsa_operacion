import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../services/inventory_page.dart';
import '../maintenance/maintenance_page.dart';
import '../services/services_catalog_page.dart';
import '../services/services_page.dart';
import '../services/warehouse_page.dart';
import '../services/weighings_page.dart';
import '../shared/app_shell.dart';
import '../shared/app_error_reporter.dart';
import '../shared/page_routes.dart';
import '../shared/dicsa_logo_mark.dart';

const double _kDashboardTitleMinWidth = 430;
const double _kWidgetSmallHeight = 132;
const double _kWidgetMediumHeight = 224;
const double _kWidgetLargeHeight = 306;
const double _kWidgetGiantHeight = 560;

class DashboardPage extends StatefulWidget {
  final bool instantOpen;
  const DashboardPage({super.key, this.instantOpen = false});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  AuthResolvedProfile? _profile;
  bool _canOpenCatalogs = false;
  bool _sideMenuCollapsed = false;
  bool _menuOverlayOpen = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveCatalogAccess());
  }

  Future<void> _resolveCatalogAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _canOpenCatalogs = AuthAccess.canOpenCatalogs(profile);
    });
  }

  Future<void> _openCatalogsFleet() async {
    if (!mounted) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.26),
      builder: (_) =>
          const ServicesCatalogPage(module: OperationsCatalogModule.flotilla),
    );
  }

  Future<void> _openCatalogsCompanies() async {
    if (!mounted) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.26),
      builder: (_) =>
          const ServicesCatalogPage(module: OperationsCatalogModule.empresas),
    );
  }

  Future<void> _openCatalogsMaterials() async {
    if (!mounted) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.26),
      builder: (_) =>
          const ServicesCatalogPage(module: OperationsCatalogModule.materiales),
    );
  }

  Future<void> _openInventoryMovements() async {
    if (!mounted) return;
    await Navigator.of(context).push(appPageRoute(page: const InventoryPage()));
  }

  Future<void> _openGeneralDashboard() async {
    if (!mounted) return;
    final profile = _profile ?? await AuthAccess.resolveCurrentProfile();
    if (!mounted || !AuthAccess.canAccessGeneralDashboard(profile)) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openInventoryProduction() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const InventoryProductionPage()));
  }

  Future<void> _openInventoryStock() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const InventoryStockPage()));
  }

  Future<void> _openServices() async {
    if (!mounted) return;
    await Navigator.of(context).push(appPageRoute(page: const ServicesPage()));
  }

  Future<void> _openWeighings() async {
    if (!mounted) return;
    await Navigator.of(context).push(appPageRoute(page: const WeighingsPage()));
  }

  Future<void> _openMaintenance() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const MaintenancePage()));
  }

  Future<void> _openWarehouse() async {
    if (!mounted) return;
    await Navigator.of(context).push(appPageRoute(page: const WarehousePage()));
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    await signOutAndRouteToLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape && _menuOverlayOpen) {
          setState(() => _menuOverlayOpen = false);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AppShell(
        background: const _DashboardBackground(),
        wrapBodyInGlass: false,
        animateHeaderSlots: false,
        animateBody: !widget.instantOpen,
        headerBodySpacing: 6,
        padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
        leadingBuilder: (_, _) => Row(
          children: [
            _HeaderIconButton(
              label: _menuOverlayOpen ? 'Cerrar navegación' : 'Navegación',
              icon: _menuOverlayOpen ? Icons.close_rounded : Icons.menu_rounded,
              onTap: () async {
                if (!mounted) return;
                setState(() => _menuOverlayOpen = !_menuOverlayOpen);
              },
            ),
          ],
        ),
        centerBuilder: (_, contentAnim) =>
            _DashboardBrand(contentAnim: contentAnim),
        trailingBuilder: (_, _) => _HeaderIconButton(
          label: 'Cerrar sesión',
          icon: Icons.logout,
          onTap: () => _logout(context),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 8, 8),
          child: LayoutBuilder(
            builder: (context, constraints) =>
                _buildDashboardBody(constraints.maxWidth < 980),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardBody(bool stacked) {
    final menu = _DashboardSideMenu(
      showGeneralDashboard: AuthAccess.canAccessGeneralDashboard(_profile),
      onOpenGeneralDashboard: _openGeneralDashboard,
      collapsed: _sideMenuCollapsed,
      onOpenInventoryMovements: _openInventoryMovements,
      onOpenInventoryProduction: _openInventoryProduction,
      onOpenInventoryStock: _openInventoryStock,
      onOpenServices: _openServices,
      onOpenWeighings: _openWeighings,
      onOpenMaintenance: _openMaintenance,
      onOpenWarehouse: _openWarehouse,
      onOpenCatalogsFleet: _canOpenCatalogs ? _openCatalogsFleet : null,
      onOpenCatalogsCompanies: _canOpenCatalogs ? _openCatalogsCompanies : null,
      onOpenCatalogsMaterials: _canOpenCatalogs ? _openCatalogsMaterials : null,
      onToggleCollapsed: () =>
          setState(() => _sideMenuCollapsed = !_sideMenuCollapsed),
    );

    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: _buildScrollableRightPanels(alignTopLeft: false),
      ),
    );

    final overlayWidth = stacked ? 280.0 : (_sideMenuCollapsed ? 220.0 : 300.0);

    return Stack(
      children: [
        content,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_menuOverlayOpen,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              opacity: _menuOverlayOpen ? 1 : 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!mounted) return;
                  setState(() => _menuOverlayOpen = false);
                },
                child: Container(color: Colors.black.withValues(alpha: 0.16)),
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          left: _menuOverlayOpen ? 0 : -(overlayWidth + 12),
          top: 0,
          width: overlayWidth,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !_menuOverlayOpen,
            child: SingleChildScrollView(child: menu),
          ),
        ),
      ],
    );
  }

  Widget _buildScrollableRightPanels({required bool alignTopLeft}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1240;
        final isMedium = constraints.maxWidth >= 900;
        final servicesPanelHeight = isWide
            ? _kWidgetGiantHeight
            : (constraints.maxHeight * 0.34).clamp(300.0, 420.0).toDouble();
        const layoutGap = 16.0;
        const horizontalPadding = 40.0;
        final availableWidth = (constraints.maxWidth - horizontalPadding).clamp(
          0.0,
          constraints.maxWidth,
        );
        final resolvedServicesWidth = (availableWidth * 0.28).clamp(
          320.0,
          420.0,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16, left: 40, right: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _InventoryYardPanel(
                        onOpenInventoryStock: _openInventoryStock,
                        onOpenInventoryProduction: _openInventoryProduction,
                      ),
                    ),
                    const SizedBox(width: layoutGap),
                    SizedBox(
                      width: resolvedServicesWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: servicesPanelHeight,
                            child: _AnimatedDashboardSummaryPanel(
                              alignTopLeft: false,
                              maxPanelWidth: resolvedServicesWidth,
                              onOpenServices: _openServices,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _DashboardOpsWidgetsColumn(
                            onOpenMaintenance: _openMaintenance,
                            onOpenWarehouse: _openWarehouse,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InventoryYardPanel(
                      onOpenInventoryStock: _openInventoryStock,
                      onOpenInventoryProduction: _openInventoryProduction,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: servicesPanelHeight,
                      child: _AnimatedDashboardSummaryPanel(
                        alignTopLeft: false,
                        maxPanelWidth: constraints.maxWidth,
                        onOpenServices: _openServices,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DashboardOpsWidgetsColumn(
                      onOpenMaintenance: _openMaintenance,
                      onOpenWarehouse: _openWarehouse,
                      compact: !isMedium,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardBrand extends StatelessWidget {
  final Animation<double> contentAnim;
  const _DashboardBrand({required this.contentAnim});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showTitle = constraints.maxWidth >= _kDashboardTitleMinWidth;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.44),
                    ),
                  ),
                  child: const Center(
                    child: DicsaLogoD(size: 52, progress: 1.0),
                  ),
                ),
                if (showTitle) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2B2B).withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Dashboard Operación',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.25,
                        height: 1.0,
                        color: Color(0xFF0B2B2B),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;

  const _HeaderIconButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final highlighted = enabled && _hovered;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: highlighted ? 1.03 : 1.0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          onTap: enabled ? () => widget.onTap!() : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 158,
            height: 48,
            transform: Matrix4.translationValues(0, highlighted ? -2 : 0, 0),
            decoration: BoxDecoration(
              color: enabled
                  ? Colors.white.withValues(alpha: 0.24)
                  : Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: enabled
                    ? Colors.white.withValues(alpha: 0.64)
                    : Colors.white.withValues(alpha: 0.32),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: highlighted ? 30 : 18,
                  color: Colors.black.withValues(
                    alpha: enabled ? (highlighted ? 0.24 : 0.11) : 0.05,
                  ),
                  offset: Offset(0, highlighted ? 16 : 10),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(widget.icon, size: 18, color: const Color(0xFF0B2B2B)),
                const SizedBox(width: 6),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B2B2B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B72FF), Color(0xFF21C9A6), Color(0xFF52F59A)],
            ),
          ),
        ),
        Positioned(
          left: -250,
          top: -120,
          child: _blurCircle(
            700,
            const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFF7ED0FF)],
            ),
          ),
        ),
        Positioned(
          right: -200,
          top: -80,
          child: _blurCircle(
            600,
            const LinearGradient(
              colors: [Color(0xFF4CFFB2), Color(0xFF00A3FF)],
            ),
          ),
        ),
        Positioned(
          left: -150,
          bottom: -250,
          child: _blurCircle(
            600,
            const LinearGradient(
              colors: [Color(0xFF0A84FF), Color(0xFF65FFE3)],
            ),
          ),
        ),
        Positioned(
          right: -120,
          bottom: -120,
          child: Container(
            width: 300,
            height: 500,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(200),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF00E0B0), Color(0xFF0080FF)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _blurCircle(double size, Gradient g) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: g),
    );
  }
}

class _DashboardSideMenu extends StatelessWidget {
  final bool showGeneralDashboard;
  final Future<void> Function()? onOpenGeneralDashboard;
  final bool collapsed;
  final Future<void> Function() onOpenInventoryMovements;
  final Future<void> Function() onOpenInventoryProduction;
  final Future<void> Function() onOpenInventoryStock;
  final Future<void> Function() onOpenServices;
  final Future<void> Function() onOpenWeighings;
  final Future<void> Function() onOpenMaintenance;
  final Future<void> Function() onOpenWarehouse;
  final Future<void> Function()? onOpenCatalogsFleet;
  final Future<void> Function()? onOpenCatalogsCompanies;
  final Future<void> Function()? onOpenCatalogsMaterials;
  final VoidCallback? onToggleCollapsed;

  const _DashboardSideMenu({
    required this.showGeneralDashboard,
    this.onOpenGeneralDashboard,
    required this.collapsed,
    required this.onOpenInventoryMovements,
    required this.onOpenInventoryProduction,
    required this.onOpenInventoryStock,
    required this.onOpenServices,
    required this.onOpenWeighings,
    required this.onOpenMaintenance,
    required this.onOpenWarehouse,
    this.onOpenCatalogsFleet,
    this.onOpenCatalogsCompanies,
    this.onOpenCatalogsMaterials,
    this.onToggleCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE40B2B2B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            color: Colors.black.withValues(alpha: 0.20),
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: collapsed
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      _DashboardSideMenuBlock(
                        icon: Icons.scale_rounded,
                        title: 'Báscula',
                        initiallyExpanded: true,
                        children: [
                          _SideMenuActionItem(
                            icon: Icons.compare_arrows_rounded,
                            title: 'Entradas y Salidas',
                            subtitle: 'Captura de movimientos IN / OUT',
                            onTap: onOpenInventoryMovements,
                          ),
                          const SizedBox(height: 8),
                          _SideMenuActionItem(
                            icon: Icons.local_shipping_outlined,
                            title: 'Viajes y Servicios',
                            subtitle: 'Programación y captura operativa',
                            onTap: onOpenServices,
                          ),
                          const SizedBox(height: 8),
                          _SideMenuActionItem(
                            icon: Icons.scale_rounded,
                            title: 'Pesadas',
                            subtitle: 'Fecha, ticket, proveedor y precio',
                            onTap: onOpenWeighings,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _DashboardSideMenuBlock(
                        icon: Icons.factory_outlined,
                        title: 'Operación',
                        initiallyExpanded: true,
                        children: [
                          _SideMenuActionItem(
                            icon: Icons.factory_outlined,
                            title: 'Producción',
                            subtitle: 'Turnos y pacas producidas',
                            onTap: onOpenInventoryProduction,
                          ),
                          const SizedBox(height: 8),
                          _SideMenuActionItem(
                            icon: Icons.inventory_2_outlined,
                            title: 'Inventario',
                            subtitle: 'Widget y detalle por material',
                            onTap: onOpenInventoryStock,
                          ),
                          const SizedBox(height: 8),
                          _SideMenuActionItem(
                            icon: Icons.warehouse_outlined,
                            title: 'Almacen',
                            subtitle: 'Inventario, movimientos y cortes',
                            onTap: onOpenWarehouse,
                          ),
                          const SizedBox(height: 8),
                          _SideMenuActionItem(
                            icon: Icons.build_circle_outlined,
                            title: 'Mantenimiento',
                            subtitle: 'Ordenes de trabajo y evidencias',
                            onTap: onOpenMaintenance,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (showGeneralDashboard)
                        _DashboardSideMenuBlock(
                          icon: Icons.dashboard_customize_rounded,
                          title: 'Accesos',
                          initiallyExpanded: true,
                          children: [
                            if (showGeneralDashboard) ...[
                              _SideMenuActionItem(
                                icon: Icons.assessment_outlined,
                                title: 'Dashboard general',
                                subtitle: 'Vista ejecutiva para dirección',
                                onTap: onOpenGeneralDashboard,
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      if (onOpenCatalogsFleet != null ||
                          onOpenCatalogsCompanies != null ||
                          onOpenCatalogsMaterials != null) ...[
                        const SizedBox(height: 12),
                        _DashboardSideMenuBlock(
                          icon: Icons.library_books_rounded,
                          title: 'Catálogos',
                          initiallyExpanded: true,
                          children: [
                            if (onOpenCatalogsFleet != null)
                              _SideMenuSubActionItem(
                                icon: Icons.badge_outlined,
                                title: 'Flotilla',
                                subtitle: 'Tabs: Chofer / Unidad',
                                onTap: onOpenCatalogsFleet,
                              ),
                            if (onOpenCatalogsFleet != null)
                              const SizedBox(height: 6),
                            if (onOpenCatalogsCompanies != null)
                              _SideMenuSubActionItem(
                                icon: Icons.business_outlined,
                                title: 'Empresas',
                                subtitle: 'Tab Empresa',
                                onTap: onOpenCatalogsCompanies,
                              ),
                            if (onOpenCatalogsCompanies != null)
                              const SizedBox(height: 6),
                            if (onOpenCatalogsMaterials != null)
                              _SideMenuSubActionItem(
                                icon: Icons.category_outlined,
                                title: 'Materiales',
                                subtitle: 'General / Comercial / Operativo',
                                onTap: onOpenCatalogsMaterials,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSideMenuBlock extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _DashboardSideMenuBlock({
    required this.icon,
    required this.title,
    required this.children,
    this.initiallyExpanded = true,
  });

  @override
  State<_DashboardSideMenuBlock> createState() =>
      _DashboardSideMenuBlockState();
}

class _DashboardSideMenuBlockState extends State<_DashboardSideMenuBlock> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  Icon(widget.icon, size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 160),
                    turns: _expanded ? 0.25 : 0.0,
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.children,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SideMenuSubActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function()? onTap;

  const _SideMenuSubActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap == null ? null : () => onTap!(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }
}

class _SideMenuActionItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function()? onTap;

  const _SideMenuActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_SideMenuActionItem> createState() => _SideMenuActionItemState();
}

class _SideMenuActionItemState extends State<_SideMenuActionItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final highlighted = enabled && _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? () => widget.onTap!() : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: highlighted
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      blurRadius: 18,
                      color: Colors.black.withValues(alpha: 0.08),
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 20, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xCCFFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedDashboardSummaryPanel extends StatelessWidget {
  final bool alignTopLeft;
  final double maxPanelWidth;
  final Future<void> Function()? onOpenServices;

  const _AnimatedDashboardSummaryPanel({
    this.alignTopLeft = false,
    this.maxPanelWidth = 920,
    this.onOpenServices,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: maxPanelWidth),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, animatedMaxWidth, child) {
        final panel = _ServicesSummaryPanel(
          maxWidth: animatedMaxWidth,
          onTap: onOpenServices,
        );
        if (!alignTopLeft) return panel;
        return Align(alignment: Alignment.topLeft, child: panel);
      },
    );
  }
}

class _ServicesSummaryPanel extends StatefulWidget {
  final double maxWidth;
  final Future<void> Function()? onTap;

  const _ServicesSummaryPanel({this.maxWidth = 920, this.onTap});

  @override
  State<_ServicesSummaryPanel> createState() => _ServicesSummaryPanelState();
}

class _ServicesSummaryPanelState extends State<_ServicesSummaryPanel>
    with WidgetsBindingObserver {
  final _supa = Supabase.instance.client;
  bool _loadingDates = true;
  bool _loadingRows = true;
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  List<DateTime> _datesWithServices = [];
  List<_ServiceSummaryItem> _items = [];
  Timer? _autoRefreshTimer;
  RealtimeChannel? _servicesRealtimeChannel;
  bool _refreshing = false;
  bool _pendingReload = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reload(showLoader: true);
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _servicesRealtimeChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestReload();
    }
  }

  void _setupAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _requestReload();
    });

    _servicesRealtimeChannel?.unsubscribe();
    _servicesRealtimeChannel = _supa
        .channel('dashboard-services-summary')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'services',
          callback: (_) {
            _requestReload();
          },
        )
        .subscribe();
  }

  void _requestReload() {
    if (!mounted) return;
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(reload());
  }

  Future<void> reload({bool showLoader = false}) async {
    if (!mounted || _refreshing) return;
    _refreshing = true;
    try {
      await _loadDates(showLoader: showLoader);
      if (_datesWithServices.isNotEmpty &&
          !_datesWithServices.contains(_selectedDate)) {
        final today = DateUtils.dateOnly(DateTime.now());
        _selectedDate = _datesWithServices.contains(today)
            ? today
            : _datesWithServices.last;
      }
      await _loadRowsForSelectedDate(showLoader: showLoader);
    } finally {
      _refreshing = false;
      if (_pendingReload) {
        _pendingReload = false;
        _requestReload();
      }
    }
  }

  DateTime _parseDate(dynamic v) {
    if (v is String && v.length >= 10) {
      final y = int.tryParse(v.substring(0, 4));
      final m = int.tryParse(v.substring(5, 7));
      final d = int.tryParse(v.substring(8, 10));
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return DateUtils.dateOnly(DateTime.now());
  }

  String _fmtDbDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _fmtStatus(String statusRaw) {
    return statusRaw
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (w) => w.isEmpty
              ? w
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _fmtDateEs(DateTime d) {
    const weekdays = <String>[
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
      'domingo',
    ];
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

    final wd = weekdays[d.weekday - 1];
    final m = months[d.month - 1];
    return '$wd ${d.day} de $m de ${d.year}';
  }

  Future<void> _loadDates({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _loadingDates = true);
    }
    final data = await _supa
        .from('services')
        .select('due_date')
        .not('due_date', 'is', null)
        .order('due_date');

    final set = <DateTime>{};
    for (final row in (data as List)) {
      final value = (row as Map<String, dynamic>)['due_date'];
      if (value == null) continue;
      set.add(DateUtils.dateOnly(_parseDate(value)));
    }

    final sorted = set.toList()..sort();
    setState(() {
      _datesWithServices = sorted;
      if (showLoader) _loadingDates = false;
    });
  }

  Future<void> _loadRowsForSelectedDate({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _loadingRows = true);
    }
    final data = await _supa
        .from('v_services_grid')
        .select('*')
        .eq('due_date', _fmtDbDate(_selectedDate))
        .order('created_at');

    final rows = (data as List).cast<Map<String, dynamic>>();
    final mapped = rows.map((row) {
      final company =
          ((row['client_name'] ?? row['client_label'] ?? 'SIN EMPRESA')
                  as String)
              .trim();
      final operator =
          ((row['driver_name'] ??
                      row['driver_full_name'] ??
                      row['driver_employee_name'] ??
                      'SIN OPERADOR')
                  as String)
              .trim();
      final status = _fmtStatus(((row['status'] ?? '') as String).trim());
      return _ServiceSummaryItem(
        company: company.isEmpty ? 'SIN EMPRESA' : company,
        operator: operator.isEmpty ? 'SIN OPERADOR' : operator,
        status: status.isEmpty ? 'Sin estado' : status,
      );
    }).toList();

    setState(() {
      _items = mapped;
      if (showLoader) _loadingRows = false;
    });
  }

  DateTime? get _prevDate {
    final prev =
        _datesWithServices.where((d) => d.isBefore(_selectedDate)).toList()
          ..sort();
    return prev.isEmpty ? null : prev.last;
  }

  DateTime? get _nextDate {
    final next =
        _datesWithServices.where((d) => d.isAfter(_selectedDate)).toList()
          ..sort();
    return next.isEmpty ? null : next.first;
  }

  Future<void> _goToDate(DateTime date) async {
    setState(() => _selectedDate = DateUtils.dateOnly(date));
    await _loadRowsForSelectedDate(showLoader: true);
  }

  @override
  Widget build(BuildContext context) {
    final loading = (_loadingDates || _loadingRows) && _items.isEmpty;
    return _HoverLift(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: widget.onTap == null ? null : () => widget.onTap!(),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.56),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.60)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Row(
                  children: [
                    _NavGlassButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      enabled: _prevDate != null,
                      onTap: _prevDate == null
                          ? null
                          : () => _goToDate(_prevDate!),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Resumen de Viajes y Servicios',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0B2B2B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _fmtDateEs(_selectedDate),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2A4B49),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_items.length} servicio${_items.length == 1 ? '' : 's'}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4B6A68),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _NavGlassButton(
                      icon: Icons.arrow_forward_ios_rounded,
                      enabled: _nextDate != null,
                      onTap: _nextDate == null
                          ? null
                          : () => _goToDate(_nextDate!),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'EMPRESA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'OPERADOR',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'ESTADO',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                if (loading)
                  const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_items.isEmpty)
                  const SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(
                        'No hay servicios para esta fecha.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2A4B49),
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 5),
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.company,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.operator,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: _StateChip(text: item.status),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardOpsWidgetsColumn extends StatelessWidget {
  final Future<void> Function() onOpenMaintenance;
  final Future<void> Function() onOpenWarehouse;
  final bool compact;

  const _DashboardOpsWidgetsColumn({
    required this.onOpenMaintenance,
    required this.onOpenWarehouse,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MaintenanceSummaryCard(onTap: onOpenMaintenance),
          const SizedBox(height: 16),
          _WarehouseSummaryCard(onTap: onOpenWarehouse),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final canSplit = constraints.maxWidth >= 860;
        if (!canSplit) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MaintenanceSummaryCard(onTap: onOpenMaintenance),
              const SizedBox(height: 16),
              _WarehouseSummaryCard(onTap: onOpenWarehouse),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _MaintenanceSummaryCard(onTap: onOpenMaintenance)),
            const SizedBox(width: 16),
            Expanded(child: _WarehouseSummaryCard(onTap: onOpenWarehouse)),
          ],
        );
      },
    );
  }
}

const List<String> _kDashboardMaintenanceFlow = <String>[
  'aviso_falla',
  'revision_area',
  'reporte_mantenimiento',
  'cotizacion',
  'autorizacion_finanzas',
  'material_recolectado',
  'programado',
  'mantenimiento_realizado',
  'supervision',
];

const Map<String, String> _kDashboardMaintenanceStatusLabel = <String, String>{
  'aviso_falla': 'Aviso falla',
  'revision_area': 'Revisión área',
  'reporte_mantenimiento': 'Reporte mantenimiento',
  'cotizacion': 'Cotización',
  'autorizacion_finanzas': 'Autorización finanzas',
  'material_recolectado': 'Material recolectado',
  'programado': 'Programado',
  'mantenimiento_realizado': 'Mantenimiento realizado',
  'supervision': 'Supervisión',
  'cerrado': 'Cerrado',
  'rechazado': 'Rechazado',
};

class _MaintenanceSummaryCard extends StatefulWidget {
  final Future<void> Function()? onTap;

  const _MaintenanceSummaryCard({this.onTap});

  @override
  State<_MaintenanceSummaryCard> createState() =>
      _MaintenanceSummaryCardState();
}

class _MaintenanceSummaryCardState extends State<_MaintenanceSummaryCard> {
  final SupabaseClient _supa = Supabase.instance.client;
  Timer? _timer;
  RealtimeChannel? _realtime;
  bool _loading = true;
  bool _refreshing = false;
  bool _pendingReload = false;
  int _openOrdersCount = 0;
  Map<String, int> _countByStage = const <String, int>{};
  List<_DashboardMaintenanceOrderItem> _openOrders = const [];

  @override
  void initState() {
    super.initState();
    _reload(showLoader: true);
    _setupRealtime();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _realtime?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 18),
      (_) => _requestReload(),
    );

    _realtime?.unsubscribe();
    _realtime = _supa
        .channel('dashboard-maintenance-summary')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_orders',
          callback: (_) => _requestReload(),
        )
        .subscribe();
  }

  void _requestReload() {
    if (!mounted) return;
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(_reload());
  }

  Future<void> _reload({bool showLoader = false}) async {
    if (!mounted || _refreshing) return;
    _refreshing = true;
    if (showLoader) {
      setState(() => _loading = true);
    }
    try {
      final rows = await _supa
          .from('maintenance_orders')
          .select('id,ot_folio,status,updated_at')
          .order('updated_at', ascending: false)
          .limit(400);
      final all = (rows as List).cast<Map<String, dynamic>>();
      final open = all.where((row) {
        final status = _normalizeStatus(row['status']);
        return status.isNotEmpty &&
            status != 'cerrado' &&
            status != 'rechazado';
      }).toList();

      final byStage = <String, int>{};
      final openOrders = <_DashboardMaintenanceOrderItem>[];
      for (final row in open) {
        final status = _normalizeStatus(row['status']);
        byStage[status] = (byStage[status] ?? 0) + 1;
        openOrders.add(
          _DashboardMaintenanceOrderItem(
            folio: (row['ot_folio'] ?? 'OT').toString().trim(),
            stage: status,
          ),
        );
      }

      byStage.removeWhere((_, value) => value <= 0);
      final sortedByStage = byStage.entries.toList()
        ..sort((a, b) {
          final aIndex = _kDashboardMaintenanceFlow.indexOf(a.key);
          final bIndex = _kDashboardMaintenanceFlow.indexOf(b.key);
          final left = aIndex < 0 ? 999 : aIndex;
          final right = bIndex < 0 ? 999 : bIndex;
          if (left != right) return left.compareTo(right);
          return a.key.compareTo(b.key);
        });

      if (!mounted) return;
      setState(() {
        _openOrdersCount = open.length;
        _countByStage = <String, int>{
          for (final entry in sortedByStage) entry.key: entry.value,
        };
        _openOrders = openOrders.take(6).toList();
        _loading = false;
      });
    } catch (e, st) {
      AppErrorReporter.report(
        e,
        st,
        fallbackMessage: 'No se pudo cargar el widget de mantenimiento.',
      );
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _refreshing = false;
      if (_pendingReload) {
        _pendingReload = false;
        _requestReload();
      }
    }
  }

  String _normalizeStatus(dynamic value) =>
      (value ?? '').toString().toLowerCase().trim();

  String _statusLabel(String status) {
    final label = _kDashboardMaintenanceStatusLabel[status];
    if (label != null) return label;
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap == null ? null : () => widget.onTap!(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryCardHeader(
                  icon: Icons.build_circle_outlined,
                  title: 'Resumen de Mantenimiento',
                  subtitle: '$_openOrdersCount OT abiertas',
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const SizedBox(
                    height: 72,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  )
                else if (_openOrdersCount == 0)
                  const SizedBox(
                    height: 58,
                    child: Center(
                      child: Text(
                        'Sin OT abiertas.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3B5A58),
                        ),
                      ),
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final entry in _countByStage.entries)
                        _SummaryCountPill(
                          label: _statusLabel(entry.key),
                          value: entry.value.toString(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  for (final order in _openOrders) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.folio,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF173937),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: _MaintenanceStageChip(
                            text: _statusLabel(order.stage),
                          ),
                        ),
                      ],
                    ),
                    if (order != _openOrders.last) const SizedBox(height: 6),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WarehouseSummaryCard extends StatefulWidget {
  final Future<void> Function()? onTap;

  const _WarehouseSummaryCard({this.onTap});

  @override
  State<_WarehouseSummaryCard> createState() => _WarehouseSummaryCardState();
}

class _WarehouseSummaryCardState extends State<_WarehouseSummaryCard> {
  final SupabaseClient _supa = Supabase.instance.client;
  Timer? _timer;
  RealtimeChannel? _realtime;
  bool _loading = true;
  bool _refreshing = false;
  bool _pendingReload = false;
  int _lowStockCount = 0;
  int _noStockCount = 0;
  List<_DashboardWarehouseStockItem> _lowStockItems = const [];

  @override
  void initState() {
    super.initState();
    _reload(showLoader: true);
    _setupRealtime();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _realtime?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _requestReload(),
    );

    _realtime?.unsubscribe();
    _realtime = _supa
        .channel('dashboard-warehouse-summary')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_items',
          callback: (_) => _requestReload(),
        )
        .subscribe();
  }

  void _requestReload() {
    if (!mounted) return;
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(_reload());
  }

  Future<void> _reload({bool showLoader = false}) async {
    if (!mounted || _refreshing) return;
    _refreshing = true;
    if (showLoader) {
      setState(() => _loading = true);
    }
    try {
      final rows = await _supa
          .from('inventory_items')
          .select('id,code,name,current_stock,minimum_stock,is_active')
          .order('name', ascending: true);
      final all = (rows as List).cast<Map<String, dynamic>>();
      final lowStock = <_DashboardWarehouseStockItem>[];
      var noStockCount = 0;
      for (final row in all) {
        final current = _toDouble(row['current_stock']);
        final minimum = _toDouble(row['minimum_stock']);
        if (current > minimum) continue;
        if (current <= 0) noStockCount += 1;
        lowStock.add(
          _DashboardWarehouseStockItem(
            code: (row['code'] ?? '').toString().trim(),
            name: (row['name'] ?? 'Sin nombre').toString().trim(),
            currentStock: current,
            minimumStock: minimum,
          ),
        );
      }

      lowStock.sort((a, b) {
        final aGap = a.minimumStock - a.currentStock;
        final bGap = b.minimumStock - b.currentStock;
        if (aGap != bGap) return bGap.compareTo(aGap);
        return a.name.compareTo(b.name);
      });

      if (!mounted) return;
      setState(() {
        _lowStockCount = lowStock.length;
        _noStockCount = noStockCount;
        _lowStockItems = lowStock.take(6).toList();
        _loading = false;
      });
    } catch (e, st) {
      AppErrorReporter.report(
        e,
        st,
        fallbackMessage: 'No se pudo cargar el widget de inventario bajo.',
      );
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _refreshing = false;
      if (_pendingReload) {
        _pendingReload = false;
        _requestReload();
      }
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _fmtQty(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap == null ? null : () => widget.onTap!(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryCardHeader(
                  icon: Icons.warehouse_outlined,
                  title: 'Resumen de Almacén',
                  subtitle: '$_lowStockCount artículos en bajo stock',
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const SizedBox(
                    height: 72,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  )
                else if (_lowStockCount == 0)
                  const SizedBox(
                    height: 58,
                    child: Center(
                      child: Text(
                        'Sin alertas de stock bajo.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3B5A58),
                        ),
                      ),
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _SummaryCountPill(
                        label: 'Bajo stock',
                        value: _lowStockCount.toString(),
                      ),
                      _SummaryCountPill(
                        label: 'Sin existencias',
                        value: _noStockCount.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  for (final item in _lowStockItems) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.code.isEmpty
                                ? item.name
                                : '${item.code} · ${item.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF173937),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_fmtQty(item.currentStock)} / ${_fmtQty(item.minimumStock)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFC75D00),
                          ),
                        ),
                      ],
                    ),
                    if (item != _lowStockItems.last) const SizedBox(height: 6),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SummaryCardHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F2F1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFF1D4C49)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0B2B2B),
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3C5A58),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCountPill extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryCountPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F1F0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1E4643),
        ),
      ),
    );
  }
}

class _MaintenanceStageChip extends StatelessWidget {
  final String text;

  const _MaintenanceStageChip({required this.text});

  Color _bgFor(String value) {
    final key = value.toLowerCase();
    if (key.contains('aviso') || key.contains('revision')) {
      return const Color(0xFFFFE0B2);
    }
    if (key.contains('cotiz') || key.contains('autoriz')) {
      return const Color(0xFFFFECB3);
    }
    if (key.contains('programado') || key.contains('realizado')) {
      return const Color(0xFFC8E6C9);
    }
    if (key.contains('supervision')) {
      return const Color(0xFFBBDEFB);
    }
    return const Color(0xFFEAF1F1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bgFor(text),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1A3A38),
        ),
      ),
    );
  }
}

class _DashboardMaintenanceOrderItem {
  final String folio;
  final String stage;

  const _DashboardMaintenanceOrderItem({
    required this.folio,
    required this.stage,
  });
}

class _DashboardWarehouseStockItem {
  final String code;
  final String name;
  final double currentStock;
  final double minimumStock;

  const _DashboardWarehouseStockItem({
    required this.code,
    required this.name,
    required this.currentStock,
    required this.minimumStock,
  });
}

const String _kDashboardInventorySite = 'DICSA_CELAYA';

class _DashboardInventoryWidgetPref {
  final String widgetKey;
  final String sourceKind;
  final String? material;
  final String? commercialMaterialCode;
  final int sortOrder;
  final bool isVisible;

  const _DashboardInventoryWidgetPref({
    required this.widgetKey,
    required this.sourceKind,
    required this.material,
    required this.commercialMaterialCode,
    required this.sortOrder,
    required this.isVisible,
  });
}

class _DashboardCommercialMaterialOption {
  final String code;
  final String name;
  final String? inventoryMaterial;

  const _DashboardCommercialMaterialOption({
    required this.code,
    required this.name,
    required this.inventoryMaterial,
  });
}

class _DashboardInventoryTileModel {
  final _DashboardInventoryWidgetPref pref;
  final String label;
  final String value;
  final String? secondaryValue;
  final Color color;

  const _DashboardInventoryTileModel({
    required this.pref,
    required this.label,
    required this.value,
    required this.secondaryValue,
    required this.color,
  });
}

class _InventoryYardPanel extends StatefulWidget {
  final Future<void> Function()? onOpenInventoryStock;
  final Future<void> Function()? onOpenInventoryProduction;

  const _InventoryYardPanel({
    this.onOpenInventoryStock,
    this.onOpenInventoryProduction,
  });

  @override
  State<_InventoryYardPanel> createState() => _InventoryYardPanelState();
}

class _InventoryYardPanelState extends State<_InventoryYardPanel> {
  final _supa = Supabase.instance.client;
  Timer? _timer;
  RealtimeChannel? _realtime;
  bool _loading = true;
  bool _refreshing = false;
  bool _pendingReload = false;
  @override
  void initState() {
    super.initState();
    _reload(showLoader: true);
    _setupRealtime();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _realtime?.unsubscribe();
    super.dispose();
  }

  final Map<String, double> _operationalOnHandKg = <String, double>{};
  final Map<String, double> _commercialOnHandKg = <String, double>{};
  final Map<String, double> _commercialOnHandKgByGeneral = <String, double>{};
  final Map<String, double> _operationalOnHandBales = <String, double>{};
  final Map<String, double> _commercialOnHandBales = <String, double>{};
  final Map<String, _DashboardCommercialMaterialOption>
  _commercialOptionsByCode = <String, _DashboardCommercialMaterialOption>{};
  List<_ProductionLineSeries> _pacaProductionSeries = const [];
  List<_ProductionLineSeries> _separationSeries = const [];
  List<_InventoryCommercialBreakdownItem> _scrapBreakdown = const [];
  List<_InventoryCommercialBreakdownItem> _paperBreakdown = const [];

  static const List<Color> _kProductionSeriesPalette = <Color>[
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFF9A825),
    Color(0xFFE53935),
    Color(0xFF6D4C41),
    Color(0xFF00897B),
    Color(0xFF3949AB),
    Color(0xFFD81B60),
  ];
  static const double _kDashboardOutgoingBaleAvgKg = 800.0;

  void _setupRealtime() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _requestReload(),
    );

    _realtime?.unsubscribe();
    _realtime = _supa
        .channel('dashboard-yard-operations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_movements_v2',
          callback: (_) => _requestReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_opening_balances_v2',
          callback: (_) => _requestReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'material_transformation_runs_v2',
          callback: (_) => _requestReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'material_transformation_run_outputs_v2',
          callback: (_) => _requestReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'material_commercial_catalog_v2',
          callback: (_) => _requestReload(),
        )
        .subscribe();
  }

  void _requestReload() {
    if (!mounted) return;
    if (_refreshing) {
      _pendingReload = true;
      return;
    }
    unawaited(_reload());
  }

  String _sqlDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  DateTime _parseDate(dynamic v) {
    if (v is DateTime) return DateUtils.dateOnly(v);
    if (v is String && v.length >= 10) {
      final y = int.tryParse(v.substring(0, 4));
      final m = int.tryParse(v.substring(5, 7));
      final d = int.tryParse(v.substring(8, 10));
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return DateUtils.dateOnly(DateTime.now());
  }

  String _normalizeOperational(String material) {
    final normalized = material.trim().toUpperCase();
    switch (normalized) {
      case 'CARTON':
      case 'CARDBOARD':
        return 'CARTON';
      case 'SCRAP':
        return 'CHATARRA';
      case 'PAPER':
        return 'PAPEL';
      case 'PLASTIC':
        return 'PLASTICO';
      case 'WOOD':
        return 'MADERA';
      case 'BALE_CAPLE':
      case 'PACA CAPLE':
      case 'PACA_CAPLE':
        return 'CAPLE';
      default:
        return normalized;
    }
  }

  bool _isBaleOperationalMaterial(String material) {
    final m = material.trim().toUpperCase();
    return m.startsWith('BALE_') || m.contains('PACA') || m == 'CAPLE';
  }

  bool _isBaleCommercialMaterialCode(String code) {
    final normalized = code.trim().toUpperCase();
    return normalized.startsWith('PACA_') ||
        normalized == 'CAPLE' ||
        normalized == 'PACA CAPLE';
  }

  String _materialUiLabel(String material) {
    switch (material.trim().toUpperCase()) {
      case 'CARTON':
        return 'Cartón';
      case 'PACA_NACIONAL':
      case 'BALE_NATIONAL':
        return 'Paca nacional';
      case 'PACA_AMERICANA':
      case 'BALE_AMERICAN':
        return 'Paca americana';
      case 'PACA_LIMPIA':
      case 'BALE_CLEAN':
        return 'Paca limpia';
      case 'PACA_BASURA':
      case 'BALE_TRASH':
        return 'Paca basura';
      case 'CAPLE':
        return 'Paca caple';
      case 'CHATARRA':
      case 'SCRAP':
        return 'Chatarra';
      case 'PAPEL':
      case 'PAPER':
        return 'Papel';
      case 'PLASTICO':
      case 'PLASTIC':
        return 'Plásticos';
      case 'MADERA':
      case 'WOOD':
        return 'Madera';
      case 'METAL':
        return 'Metal';
      default:
        return material;
    }
  }

  int _materialSortOrder(String material) {
    const preferred = <String>[
      'PACA_NACIONAL',
      'PACA_AMERICANA',
      'PACA_LIMPIA',
      'PACA_BASURA',
      'CAPLE',
      'CHATARRA',
      'METAL',
      'PAPEL',
      'PLASTICO',
      'MADERA',
    ];
    final upper = material.trim().toUpperCase();
    final idx = preferred.indexOf(upper);
    return idx >= 0 ? idx : 999;
  }

  List<_DashboardInventoryWidgetPref> _fixedWidgetPrefs() {
    const defaults = <Map<String, String?>>[
      {'source_kind': 'bales_total'},
      {'source_kind': 'operational_material', 'material': 'CARTON'},
      {'source_kind': 'operational_material', 'material': 'CHATARRA'},
      {'source_kind': 'operational_material', 'material': 'METAL'},
      {'source_kind': 'operational_material', 'material': 'PAPEL'},
      {'source_kind': 'operational_material', 'material': 'PLASTICO'},
      {'source_kind': 'operational_material', 'material': 'MADERA'},
      {
        'source_kind': 'commercial_material',
        'commercial_material_code': 'PACA_NACIONAL',
      },
      {
        'source_kind': 'commercial_material',
        'commercial_material_code': 'PACA_AMERICANA',
      },
      {
        'source_kind': 'commercial_material',
        'commercial_material_code': 'PACA_LIMPIA',
      },
      {
        'source_kind': 'commercial_material',
        'commercial_material_code': 'PACA_BASURA',
      },
      {
        'source_kind': 'commercial_material',
        'commercial_material_code': 'CAPLE',
      },
    ];
    return [
      for (var i = 0; i < defaults.length; i++)
        _DashboardInventoryWidgetPref(
          widgetKey:
              'default_${i + 1}_${defaults[i]['source_kind']}_${defaults[i]['material'] ?? 'total'}',
          sourceKind: defaults[i]['source_kind']!,
          material: defaults[i]['material'],
          commercialMaterialCode: defaults[i]['commercial_material_code'],
          sortOrder: i,
          isVisible: true,
        ),
    ];
  }

  Color _tileColorForMaterial(String? material) {
    switch ((material ?? '').trim().toUpperCase()) {
      case 'SCRAP':
        return const Color(0xFFE3F1FF);
      case 'PAPER':
        return const Color(0xFFEAF6E3);
      case 'PLASTIC':
        return const Color(0xFFFFF2D8);
      case 'WOOD':
        return const Color(0xFFF0E6D8);
      default:
        return const Color(0xFFE0F3FF);
    }
  }

  String _tileLabelForOperationalMaterial(String material) {
    final label = _materialUiLabel(material);
    return _isBaleOperationalMaterial(material) ? label : '$label en patio';
  }

  double _yardKgForOperationalMaterial(String material) {
    final normalized = _normalizeOperational(material);
    final operationalKg = _operationalOnHandKg[normalized] ?? 0;
    final commercialKg = _commercialOnHandKgByGeneral[normalized] ?? 0;
    return operationalKg + commercialKg;
  }

  Future<void> _reload({bool showLoader = false}) async {
    if (!mounted || _refreshing) return;
    _refreshing = true;
    if (showLoader) {
      setState(() => _loading = true);
    }
    try {
      final asOfDate = DateUtils.dateOnly(DateTime.now());
      final trendStart = DateUtils.dateOnly(
        asOfDate.subtract(const Duration(days: 89)),
      );
      final responses = await Future.wait<dynamic>([
        _supa
            .from('v_inventory_general_balance_v2')
            .select(
              'code,name,opening_kg,movement_kg,on_hand_kg,opening_units,movement_units,on_hand_units',
            ),
        _supa
            .from('v_inventory_commercial_balance_v2')
            .select(
              'code,name,family,general_code,opening_kg,movement_kg,on_hand_kg,on_hand_units',
            ),
        _supa
            .from('material_commercial_catalog_v2')
            .select('code,name,general_material:general_material_id(code)')
            .eq('is_active', true),
        _supa
            .from('material_transformation_runs_v2')
            .select(
              'id,op_date,source_general_material:source_general_material_id(code),input_weight_kg',
            )
            .or('site.eq.$_kDashboardInventorySite,site.is.null')
            .gte('op_date', _sqlDate(trendStart))
            .lte('op_date', _sqlDate(asOfDate)),
        _supa
            .from('material_transformation_run_outputs_v2')
            .select(
              'run_id,output_weight_kg,output_unit_count,'
              'commercial_material:commercial_material_id(code,name,general_material:general_material_id(code)),'
              'run:run_id(op_date,source_general_material:source_general_material_id(code),site)',
            )
            .gte('run.op_date', _sqlDate(trendStart))
            .lte('run.op_date', _sqlDate(asOfDate)),
      ]);

      final generalBalanceRows = (responses[0] as List)
          .cast<Map<String, dynamic>>();
      final commercialBalanceRows = (responses[1] as List)
          .cast<Map<String, dynamic>>();
      final catalogRows = (responses[2] as List).cast<Map<String, dynamic>>();
      final transformationOutputs = (responses[4] as List)
          .cast<Map<String, dynamic>>();

      final operational = <String, double>{};
      for (final row in generalBalanceRows) {
        final material = _normalizeOperational((row['code'] ?? '').toString());
        if (material.isEmpty) continue;
        operational[material] = _num(row['on_hand_kg']);
      }
      final commercialNames = <String, String>{
        for (final row in catalogRows)
          (row['code'] ?? '').toString(): (row['name'] ?? '').toString(),
      };
      final commercialOptionsByCode =
          <String, _DashboardCommercialMaterialOption>{
            for (final row in catalogRows)
              (row['code'] ?? '')
                  .toString(): _DashboardCommercialMaterialOption(
                code: (row['code'] ?? '').toString(),
                name: (row['name'] ?? '').toString(),
                inventoryMaterial:
                    ((((row['general_material'] as Map?) ?? const {})['code']))
                        .toString(),
              ),
          };
      final commercialOnHand = <String, double>{};
      final commercialOnHandByGeneral = <String, double>{};
      final operationalBales = <String, double>{};
      final commercialBales = <String, double>{};
      final scrapByCommercial = <String, double>{};
      final paperByCommercial = <String, double>{};
      final dailyProductionByMaterialAndDate =
          <String, Map<DateTime, double>>{};
      final dailySeparationByCommercialAndDate =
          <String, Map<DateTime, double>>{};

      for (final row in commercialBalanceRows) {
        final code = (row['code'] ?? '').toString().trim();
        if (code.isEmpty) continue;
        final weightKg = _num(row['on_hand_kg']);
        final generalCode = _normalizeOperational(
          (row['general_code'] ?? '').toString(),
        );
        commercialOnHand[code] = weightKg;
        if (generalCode.isNotEmpty) {
          commercialOnHandByGeneral[generalCode] =
              (commercialOnHandByGeneral[generalCode] ?? 0) + weightKg;
        }
        final movementIsBale =
            _isBaleOperationalMaterial(code) ||
            _isBaleCommercialMaterialCode(code);
        final onHandUnits = _num(row['on_hand_units']);
        if (movementIsBale) {
          commercialBales[code] = onHandUnits > 0
              ? onHandUnits
              : (_kDashboardOutgoingBaleAvgKg > 0
                    ? weightKg / _kDashboardOutgoingBaleAvgKg
                    : 0);
        }
        if (generalCode == 'CHATARRA') {
          scrapByCommercial[code] = weightKg;
        } else if (generalCode == 'PAPEL') {
          paperByCommercial[code] = weightKg;
        }
      }

      for (final row in transformationOutputs) {
        final run = (row['run'] as Map?)?.cast<String, dynamic>();
        final commercial = (row['commercial_material'] as Map?)
            ?.cast<String, dynamic>();
        final commercialCode = (commercial?['code'] ?? '').toString().trim();
        if (commercialCode.isEmpty) continue;
        final opDate = DateUtils.dateOnly(_parseDate(run?['op_date']));
        final generalCode = _normalizeOperational(
          (((commercial?['general_material'] as Map?) ?? const {})['code'] ??
                  ((run?['source_general_material'] as Map?) ??
                      const {})['code'])
              .toString(),
        );
        final outputKg = _num(row['output_weight_kg']);
        final outputUnits = _num(row['output_unit_count']);
        if (generalCode == 'CARTON') {
          final key = _normalizeOperational(commercialCode);
          final producedBales = outputUnits > 0
              ? outputUnits
              : (outputKg > 0 && _kDashboardOutgoingBaleAvgKg > 0
                    ? outputKg / _kDashboardOutgoingBaleAvgKg
                    : 0);
          final perDay = dailyProductionByMaterialAndDate.putIfAbsent(
            key,
            () => <DateTime, double>{},
          );
          perDay[opDate] = (perDay[opDate] ?? 0) + producedBales;
        }
        if (generalCode == 'CHATARRA' || generalCode == 'PAPEL') {
          final perDay = dailySeparationByCommercialAndDate.putIfAbsent(
            commercialCode,
            () => <DateTime, double>{},
          );
          perDay[opDate] = (perDay[opDate] ?? 0) + outputKg;
        }
      }

      final scrap = <_InventoryCommercialBreakdownItem>[
        for (final entry in scrapByCommercial.entries)
          _InventoryCommercialBreakdownItem(
            code: entry.key,
            name: commercialNames[entry.key] ?? entry.key,
            kg: entry.value,
          ),
      ]..sort((a, b) => b.kg.compareTo(a.kg));

      final paper = <_InventoryCommercialBreakdownItem>[
        for (final entry in paperByCommercial.entries)
          _InventoryCommercialBreakdownItem(
            code: entry.key,
            name: commercialNames[entry.key] ?? entry.key,
            kg: entry.value,
          ),
      ]..sort((a, b) => b.kg.compareTo(a.kg));

      final dayAxis = <DateTime>[];
      for (
        var d = trendStart;
        !d.isAfter(asOfDate);
        d = d.add(const Duration(days: 1))
      ) {
        dayAxis.add(d);
      }

      _ProductionLineSeries buildSeries(String material, Color color) {
        final perDay = dailyProductionByMaterialAndDate[material]!;
        final points = dayAxis
            .map((d) => _DailyPoint(day: d, value: perDay[d] ?? 0))
            .toList();
        return _ProductionLineSeries(
          label: _materialUiLabel(material),
          color: color,
          points: points,
          unitLabel: 'pacas',
        );
      }

      _ProductionLineSeries buildSeparationSeries(
        String commercialCode,
        Color color,
      ) {
        final perDay = dailySeparationByCommercialAndDate[commercialCode]!;
        final points = dayAxis
            .map((d) => _DailyPoint(day: d, value: perDay[d] ?? 0))
            .toList();
        return _ProductionLineSeries(
          label: commercialNames[commercialCode] ?? commercialCode,
          color: color,
          points: points,
          unitLabel: 'kg',
        );
      }

      final productionMaterials = dailyProductionByMaterialAndDate.keys.toList()
        ..sort((a, b) {
          final byOrder = _materialSortOrder(
            a,
          ).compareTo(_materialSortOrder(b));
          if (byOrder != 0) return byOrder;
          return a.compareTo(b);
        });
      final pacaProductionSeries = <_ProductionLineSeries>[
        for (var i = 0; i < productionMaterials.length; i++)
          buildSeries(
            productionMaterials[i],
            _kProductionSeriesPalette[i % _kProductionSeriesPalette.length],
          ),
      ];
      final separationMaterials =
          dailySeparationByCommercialAndDate.keys.toList()..sort((a, b) {
            final totalA = dailySeparationByCommercialAndDate[a]!.values.fold(
              0.0,
              (sum, value) => sum + value,
            );
            final totalB = dailySeparationByCommercialAndDate[b]!.values.fold(
              0.0,
              (sum, value) => sum + value,
            );
            final byWeight = totalB.compareTo(totalA);
            if (byWeight != 0) return byWeight;
            final labelA = commercialNames[a] ?? a;
            final labelB = commercialNames[b] ?? b;
            return labelA.compareTo(labelB);
          });
      final separationSeries = <_ProductionLineSeries>[
        for (var i = 0; i < separationMaterials.length; i++)
          buildSeparationSeries(
            separationMaterials[i],
            _kProductionSeriesPalette[(i + pacaProductionSeries.length) %
                _kProductionSeriesPalette.length],
          ),
      ];

      if (!mounted) return;
      setState(() {
        _operationalOnHandKg
          ..clear()
          ..addAll(operational);
        _commercialOnHandKg
          ..clear()
          ..addAll(commercialOnHand);
        _commercialOnHandKgByGeneral
          ..clear()
          ..addAll(commercialOnHandByGeneral);
        _operationalOnHandBales
          ..clear()
          ..addAll(operationalBales);
        _commercialOnHandBales
          ..clear()
          ..addAll(commercialBales);
        _commercialOptionsByCode
          ..clear()
          ..addAll(commercialOptionsByCode);
        _pacaProductionSeries = pacaProductionSeries;
        _separationSeries = separationSeries;
        _scrapBreakdown = scrap;
        _paperBreakdown = paper;
        _loading = false;
      });
    } catch (e, st) {
      AppErrorReporter.report(
        e,
        st,
        fallbackMessage: 'No se pudo cargar la informacion del dashboard.',
      );
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _refreshing = false;
      if (_pendingReload) {
        _pendingReload = false;
        _requestReload();
      }
    }
  }

  String _fmtKg(double value) => '${value.toStringAsFixed(1)} kg';

  _DashboardInventoryTileModel? _buildTileModel(
    _DashboardInventoryWidgetPref pref,
    Map<String, double> baleByMaterial,
    double totalPacasKg,
  ) {
    switch (pref.sourceKind) {
      case 'bales_total':
        final totalPacas = baleByMaterial.entries.fold<double>(
          0,
          (sum, entry) => sum + entry.value,
        );
        return _DashboardInventoryTileModel(
          pref: pref,
          label: 'Pacas en patio',
          value: '${totalPacas.toStringAsFixed(0)} pacas',
          secondaryValue: _fmtKg(totalPacasKg),
          color: const Color(0xFFD6F4FF),
        );
      case 'operational_material':
        final material = _normalizeOperational((pref.material ?? '').trim());
        if (material.isEmpty) return null;
        final kg = _yardKgForOperationalMaterial(material);
        final isBale = _isBaleOperationalMaterial(material);
        final fallbackCommercialBales = _commercialOnHandBales[material] ?? 0;
        final baleCount = (_operationalOnHandBales[material] ?? 0) > 0
            ? (_operationalOnHandBales[material] ?? 0)
            : fallbackCommercialBales;
        return _DashboardInventoryTileModel(
          pref: pref,
          label: _tileLabelForOperationalMaterial(material),
          value: isBale ? '${baleCount.toStringAsFixed(0)} pacas' : _fmtKg(kg),
          secondaryValue: isBale ? _fmtKg(kg) : 'Existencia actual',
          color: _tileColorForMaterial(material),
        );
      case 'commercial_material':
        final code = (pref.commercialMaterialCode ?? '').trim();
        if (code.isEmpty) return null;
        final option = _commercialOptionsByCode[code];
        final kg = _commercialOnHandKg[code] ?? 0;
        final inventoryMaterial = _normalizeOperational(
          option?.inventoryMaterial ?? '',
        );
        final isBale =
            _isBaleOperationalMaterial(inventoryMaterial) ||
            _isBaleCommercialMaterialCode(code);
        final baleCount = _commercialOnHandBales[code] ?? 0;
        return _DashboardInventoryTileModel(
          pref: pref,
          label: option?.name.isNotEmpty == true ? option!.name : code,
          value: isBale ? '${baleCount.toStringAsFixed(0)} pacas' : _fmtKg(kg),
          secondaryValue: isBale
              ? _fmtKg(kg)
              : _materialUiLabel(option?.inventoryMaterial ?? ''),
          color: _tileColorForMaterial(option?.inventoryMaterial),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baleByMaterial = <String, double>{};
    final baleKgByMaterial = <String, double>{};
    for (final entry in _operationalOnHandBales.entries) {
      if (!_isBaleOperationalMaterial(entry.key)) continue;
      final key = _normalizeOperational(entry.key);
      baleByMaterial[key] = (baleByMaterial[key] ?? 0) + entry.value;
      baleKgByMaterial[key] =
          (baleKgByMaterial[key] ?? 0) + (_operationalOnHandKg[entry.key] ?? 0);
    }
    for (final entry in _commercialOnHandBales.entries) {
      if (!_isBaleCommercialMaterialCode(entry.key)) continue;
      final key = _normalizeOperational(entry.key);
      baleByMaterial[key] = (baleByMaterial[key] ?? 0) + entry.value;
      baleKgByMaterial[key] =
          (baleKgByMaterial[key] ?? 0) + (_commercialOnHandKg[entry.key] ?? 0);
    }
    for (final key in const <String>[
      'BALE_NATIONAL',
      'BALE_AMERICAN',
      'BALE_CLEAN',
      'BALE_TRASH',
      'CAPLE',
    ]) {
      baleByMaterial.putIfAbsent(key, () => 0);
      baleKgByMaterial.putIfAbsent(key, () => 0);
    }
    final totalPacasKg = baleKgByMaterial.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final visiblePrefs =
        _fixedWidgetPrefs().where((pref) => pref.isVisible).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final tileModels = visiblePrefs
        .map((pref) => _buildTileModel(pref, baleByMaterial, totalPacasKg))
        .whereType<_DashboardInventoryTileModel>()
        .toList();

    return _loading && _operationalOnHandKg.isEmpty
        ? const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final width = constraints.maxWidth;
              final desktopGrid = width >= 900;
              final smallW = desktopGrid
                  ? (width - (2 * gap)) / 3
                  : ((width - gap) / 2).clamp(120.0, 520.0);
              final mediumW = desktopGrid ? (width - gap) / 2 : width;
              final tiles = Wrap(
                spacing: gap,
                runSpacing: gap,
                children: tileModels
                    .map(
                      (tile) => _SquareTile(
                        tile: tile,
                        width: smallW,
                        editMode: false,
                        isSelected: false,
                        onTap: widget.onOpenInventoryProduction,
                      ),
                    )
                    .toList(),
              );

              final chart = _ChartCard(
                title: 'Transformación diaria de cartón',
                subtitle: 'Kg clasificados por material comercial',
                onTap: widget.onOpenInventoryProduction,
                child: _ProductionBarChart(seriesList: _pacaProductionSeries),
              );
              final separationChart = _ChartCard(
                title: 'Transformación diaria de patio',
                subtitle: 'Kg clasificados por día en chatarra y papel',
                onTap: widget.onOpenInventoryProduction,
                child: _ProductionBarChart(seriesList: _separationSeries),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tiles,
                  const SizedBox(height: 10),
                  SizedBox(height: _kWidgetLargeHeight, child: chart),
                  const SizedBox(height: 10),
                  SizedBox(height: _kWidgetLargeHeight, child: separationChart),
                  const SizedBox(height: 10),
                  _OperationalBreakdownCard(
                    scrap: _scrapBreakdown,
                    paper: _paperBreakdown,
                    mediumCardWidth: mediumW,
                    cardGap: gap,
                    onTap: widget.onOpenInventoryProduction,
                  ),
                ],
              );
            },
          );
  }
}

class _InventoryCommercialBreakdownItem {
  final String code;
  final String name;
  final double kg;

  const _InventoryCommercialBreakdownItem({
    required this.code,
    required this.name,
    required this.kg,
  });
}

class _DailyPoint {
  final DateTime day;
  final double value;

  const _DailyPoint({required this.day, required this.value});
}

class _ProductionLineSeries {
  final String label;
  final Color color;
  final List<_DailyPoint> points;
  final String unitLabel;

  const _ProductionLineSeries({
    required this.label,
    required this.color,
    required this.points,
    this.unitLabel = 'pacas',
  });
}

class _SquareTile extends StatelessWidget {
  final _DashboardInventoryTileModel tile;
  final double width;
  final Future<void> Function()? onTap;
  final bool editMode;
  final bool isSelected;

  const _SquareTile({
    required this.tile,
    required this.width,
    this.onTap,
    this.editMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap == null ? null : () => onTap!(),
          child: Container(
            width: width,
            constraints: const BoxConstraints(minHeight: _kWidgetSmallHeight),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.40),
                  tile.color.withValues(alpha: 0.56),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0B72FF).withValues(alpha: 0.88)
                    : Colors.white.withValues(alpha: 0.80),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 16,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 6),
                  color: const Color(0x1A0B2B2B),
                ),
                BoxShadow(
                  blurRadius: 10,
                  spreadRadius: -2,
                  offset: const Offset(0, -2),
                  color: Colors.white.withValues(alpha: 0.34),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (editMode)
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0B72FF)
                            : Colors.white.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(
                            0xFF0B72FF,
                          ).withValues(alpha: isSelected ? 0.95 : 0.35),
                        ),
                      ),
                    ),
                  ),
                Text(
                  tile.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D3B39),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tile.value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0B2B2B),
                  ),
                ),
                if (tile.secondaryValue != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    tile.secondaryValue!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3D5E5B),
                    ),
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

class _OperationalBreakdownCard extends StatelessWidget {
  final List<_InventoryCommercialBreakdownItem> scrap;
  final List<_InventoryCommercialBreakdownItem> paper;
  final double? mediumCardWidth;
  final double cardGap;
  final Future<void> Function()? onTap;

  const _OperationalBreakdownCard({
    required this.scrap,
    required this.paper,
    this.mediumCardWidth,
    this.cardGap = 10,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalScrap = scrap.fold<double>(0, (sum, item) => sum + item.kg);
    final totalPaper = paper.fold<double>(0, (sum, item) => sum + item.kg);
    final blocks = <_OperationalBlockData>[
      _OperationalBlockData(
        heading: 'Chatarra',
        accent: const Color(0xFF1F95E0),
        items: scrap,
        totalKg: totalScrap,
      ),
      _OperationalBlockData(
        heading: 'Papel',
        accent: const Color(0xFF4B8F52),
        items: paper,
        totalKg: totalPaper,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final canUseMedium =
                mediumCardWidth != null &&
                constraints.maxWidth >=
                    ((mediumCardWidth! * 2) + cardGap - 0.5);
            final columns = canUseMedium
                ? 2
                : (constraints.maxWidth < 840 ? 1 : 2);
            final width = canUseMedium
                ? mediumCardWidth!
                : (constraints.maxWidth - ((columns - 1) * cardGap)) / columns;
            return Wrap(
              spacing: cardGap,
              runSpacing: cardGap,
              children: blocks
                  .map(
                    (block) => SizedBox(
                      width: width,
                      height: _kWidgetMediumHeight,
                      child: _OperationalBreakdownTable(
                        heading: block.heading,
                        accent: block.accent,
                        items: block.items,
                        totalKg: block.totalKg,
                        onTap: onTap,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _OperationalBlockData {
  final String heading;
  final Color accent;
  final List<_InventoryCommercialBreakdownItem> items;
  final double totalKg;

  const _OperationalBlockData({
    required this.heading,
    required this.accent,
    required this.items,
    required this.totalKg,
  });
}

class _OperationalBreakdownTable extends StatelessWidget {
  final String heading;
  final Color accent;
  final List<_InventoryCommercialBreakdownItem> items;
  final double totalKg;
  final Future<void> Function()? onTap;

  const _OperationalBreakdownTable({
    required this.heading,
    required this.accent,
    required this.items,
    required this.totalKg,
    this.onTap,
  });

  String _fmtKg(double value) => '${value.toStringAsFixed(1)} kg';

  @override
  Widget build(BuildContext context) {
    final shown = items.take(8).toList();
    return _HoverLift(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap == null ? null : () => onTap!(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        heading,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF173937),
                        ),
                      ),
                    ),
                    Text(
                      _fmtKg(totalKg),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF355957),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (shown.isEmpty)
                  const Text(
                    'Sin materiales comerciales.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5A7977),
                    ),
                  )
                else
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: true),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: shown.length,
                        itemBuilder: (_, i) {
                          final item = shown[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF244846),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _fmtKg(item.kg),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF355957),
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Future<void> Function()? onTap;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap == null ? null : () => onTap!(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.46),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F3D3A),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4B6A68),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverLift extends StatefulWidget {
  final Widget child;

  const _HoverLift({required this.child});

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()
          ..translateByDouble(0.0, _hovered ? -4.0 : 0.0, 0.0, 1.0)
          ..scaleByDouble(
            _hovered ? 1.008 : 1.0,
            _hovered ? 1.008 : 1.0,
            1.0,
            1.0,
          ),
        child: widget.child,
      ),
    );
  }
}

class _ProductionBarChart extends StatefulWidget {
  final List<_ProductionLineSeries> seriesList;

  const _ProductionBarChart({required this.seriesList});

  @override
  State<_ProductionBarChart> createState() => _ProductionBarChartState();
}

class _ProductionBarChartState extends State<_ProductionBarChart> {
  static const double _axisWidth = 44;
  static const double _leftPad = 8;
  static const double _rightPad = 10;
  static const double _topPad = 8;
  static const double _bottomPad = 34;
  static const double _visibleDays = 14;

  final ScrollController _scrollController = ScrollController();
  _HoveredBarInfo? _hovered;
  bool _stickToLatest = true;

  @override
  void initState() {
    super.initState();
    _jumpToLatest();
  }

  @override
  void didUpdateWidget(covariant _ProductionBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesList != widget.seriesList) {
      _hovered = null;
      if (_stickToLatest) {
        _jumpToLatest();
      }
    }
  }

  void _jumpToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seriesList.isEmpty ||
        widget.seriesList.every((s) => s.points.isEmpty)) {
      return const Center(
        child: Text(
          'Sin datos suficientes.',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF4B6A68),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = widget.seriesList.first.points.length;
        final plotHeight = math.max(80.0, constraints.maxHeight - 30);
        final viewportWidth = math.max(
          120.0,
          constraints.maxWidth - _axisWidth,
        );
        final dayStep = viewportWidth / _visibleDays;
        final contentWidth = math.max(
          constraints.maxWidth - _axisWidth,
          _leftPad + _rightPad + (count * dayStep),
        );
        final maxY = _computeMaxY(widget.seriesList);
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: _axisWidth,
                    height: plotHeight,
                    child: CustomPaint(
                      painter: _FixedYAxisPainter(
                        maxY: maxY,
                        topPad: _topPad,
                        bottomPad: _bottomPad,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Expanded(
                    child: MouseRegion(
                      onExit: (_) => setState(() => _hovered = null),
                      onHover: (event) {
                        final hit = _hitTestBar(
                          event.localPosition,
                          viewportSize: Size(
                            constraints.maxWidth - _axisWidth,
                            plotHeight,
                          ),
                          contentWidth: contentWidth,
                          dayStep: dayStep,
                          maxY: maxY,
                        );
                        if (hit?.key == _hovered?.key) return;
                        setState(() => _hovered = hit);
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: (details) {
                          if (!_scrollController.hasClients) return;
                          _stickToLatest = false;
                          final max =
                              _scrollController.position.maxScrollExtent;
                          if (max <= 0) return;
                          final next =
                              (_scrollController.offset - details.delta.dx)
                                  .clamp(0.0, max);
                          _scrollController.jumpTo(next);
                        },
                        onHorizontalDragStart: (_) =>
                            setState(() => _hovered = null),
                        child: Stack(
                          children: [
                            SingleChildScrollView(
                              controller: _scrollController,
                              scrollDirection: Axis.horizontal,
                              physics: const ClampingScrollPhysics(),
                              primary: false,
                              child: SizedBox(
                                width: contentWidth,
                                height: plotHeight,
                                child: CustomPaint(
                                  painter: _ProductionBarChartPainter(
                                    seriesList: widget.seriesList,
                                    maxY: maxY,
                                    leftPad: _leftPad,
                                    rightPad: _rightPad,
                                    topPad: _topPad,
                                    bottomPad: _bottomPad,
                                    dayStep: dayStep,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                            if (_hovered != null)
                              Positioned(
                                left: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _hovered!.color.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '${_hovered!.label} · ${_hovered!.dayLabel} · ${_hovered!.value.toStringAsFixed(0)} ${_hovered!.unitLabel}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF223A39),
                                    ),
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
            const SizedBox(height: 6),
            SizedBox(
              height: 24,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.seriesList
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: s.color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                s.label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF365653),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  _HoveredBarInfo? _hitTestBar(
    Offset p, {
    required Size viewportSize,
    required double contentWidth,
    required double dayStep,
    required double maxY,
  }) {
    if (widget.seriesList.isEmpty) return null;
    final count = widget.seriesList.first.points.length;
    if (count == 0) return null;

    final left = _leftPad;
    final top = _topPad;
    final right = contentWidth - _rightPad;
    final bottom = viewportSize.height - _bottomPad;
    final xInContent =
        p.dx + (_scrollController.hasClients ? _scrollController.offset : 0);
    final yInContent = p.dy;
    if (xInContent < left ||
        xInContent > right ||
        yInContent < top ||
        yInContent > bottom) {
      return null;
    }
    final h = math.max(1.0, bottom - top);

    final dayIndex = ((xInContent - left) / dayStep).floor().clamp(
      0,
      count - 1,
    );
    final dayStartX = left + (dayIndex * dayStep);
    final groupWidth = math.min(30.0, dayStep - 4);
    final seriesCount = widget.seriesList.length;
    final barGap = 2.0;
    final barWidth = math.max(
      2.5,
      (groupWidth - ((seriesCount - 1) * barGap)) / seriesCount,
    );
    final groupLeft = dayStartX + ((dayStep - groupWidth) / 2);

    for (var s = 0; s < seriesCount; s++) {
      final x = groupLeft + s * (barWidth + barGap);
      final value = widget.seriesList[s].points[dayIndex].value;
      final barTop = bottom - ((value / maxY) * h);
      final rect = Rect.fromLTRB(x, barTop, x + barWidth, bottom);
      if (rect.inflate(2).contains(Offset(xInContent, yInContent))) {
        final day = widget.seriesList[s].points[dayIndex].day;
        return _HoveredBarInfo(
          dayIndex: dayIndex,
          seriesIndex: s,
          label: widget.seriesList[s].label,
          color: widget.seriesList[s].color,
          value: value,
          unitLabel: widget.seriesList[s].unitLabel,
          dayLabel:
              '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}',
        );
      }
    }
    return null;
  }

  double _computeMaxY(List<_ProductionLineSeries> seriesList) {
    final values = <double>[
      for (final line in seriesList) ...line.points.map((e) => e.value),
    ];
    if (values.isEmpty) return 1;
    return math.max(1.0, values.reduce(math.max) * 1.10);
  }
}

class _ProductionBarChartPainter extends CustomPainter {
  final List<_ProductionLineSeries> seriesList;
  final double maxY;
  final double leftPad;
  final double rightPad;
  final double topPad;
  final double bottomPad;
  final double dayStep;

  const _ProductionBarChartPainter({
    required this.seriesList,
    required this.maxY,
    required this.leftPad,
    required this.rightPad,
    required this.topPad,
    required this.bottomPad,
    required this.dayStep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final axisColor = const Color(0xFFB7CFCC);
    final left = leftPad;
    final top = topPad;
    final right = size.width - rightPad;
    final bottom = size.height - bottomPad;
    final h = math.max(1.0, bottom - top);

    final values = <double>[
      for (final line in seriesList) ...line.points.map((e) => e.value),
    ];
    if (values.isEmpty) return;
    final count = seriesList.first.points.length;
    final seriesCount = seriesList.length;
    final barGap = 2.0;
    final groupWidth = math.min(30.0, dayStep - 4);
    final barWidth = math.max(
      2.5,
      (groupWidth - ((seriesCount - 1) * barGap)) / seriesCount,
    );

    final gridPaint = Paint()
      ..color = axisColor.withValues(alpha: 0.65)
      ..strokeWidth = 1;
    const yTicks = 5;
    for (var i = 0; i < yTicks; i++) {
      final ratio = i / (yTicks - 1);
      final y = bottom - (h * ratio);
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
    }

    for (var i = 0; i < count; i++) {
      final x = left + (i * dayStep) + (dayStep / 2);
      canvas.drawLine(
        Offset(x, top + 2),
        Offset(x, bottom),
        Paint()
          ..color = axisColor.withValues(alpha: 0.18)
          ..strokeWidth = 1,
      );
      final baseX = left + (i * dayStep) + ((dayStep - groupWidth) / 2);
      for (var s = 0; s < seriesCount; s++) {
        final value = seriesList[s].points[i].value;
        final barHeight = (value / maxY) * h;
        final rect = Rect.fromLTWH(
          baseX + (s * (barWidth + barGap)),
          bottom - barHeight,
          barWidth,
          barHeight,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()
            ..color = seriesList[s].color
            ..style = PaintingStyle.fill,
        );
      }
      final d = seriesList.first.points[i].day;
      final label =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5A7573),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (x - (tp.width / 2)).clamp(left, right - tp.width);
      tp.paint(canvas, Offset(dx, bottom + 4));
    }

    canvas.drawLine(
      Offset(left, bottom),
      Offset(right, bottom),
      Paint()
        ..color = axisColor.withValues(alpha: 0.75)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _ProductionBarChartPainter oldDelegate) {
    return oldDelegate.seriesList != seriesList;
  }
}

class _HoveredBarInfo {
  final int dayIndex;
  final int seriesIndex;
  final String label;
  final Color color;
  final double value;
  final String unitLabel;
  final String dayLabel;

  const _HoveredBarInfo({
    required this.dayIndex,
    required this.seriesIndex,
    required this.label,
    required this.color,
    required this.value,
    required this.unitLabel,
    required this.dayLabel,
  });

  String get key => '$dayIndex|$seriesIndex|$value';
}

class _FixedYAxisPainter extends CustomPainter {
  final double maxY;
  final double topPad;
  final double bottomPad;

  const _FixedYAxisPainter({
    required this.maxY,
    required this.topPad,
    required this.bottomPad,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const yTicks = 5;
    final axisColor = const Color(0xFFB7CFCC);
    final left = size.width - 1.0;
    final top = topPad;
    final bottom = size.height - bottomPad;
    final h = math.max(1.0, bottom - top);

    for (var i = 0; i < yTicks; i++) {
      final ratio = i / (yTicks - 1);
      final y = bottom - (h * ratio);
      canvas.drawLine(
        Offset(left - 6, y),
        Offset(left, y),
        Paint()
          ..color = axisColor.withValues(alpha: 0.7)
          ..strokeWidth = 1,
      );
      final val = maxY * ratio;
      final tp = TextPainter(
        text: TextSpan(
          text: val.toStringAsFixed(0),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5A7573),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 8);
      tp.paint(canvas, Offset(size.width - tp.width - 8, y - (tp.height / 2)));
    }

    canvas.drawLine(
      Offset(left, top),
      Offset(left, bottom),
      Paint()
        ..color = axisColor.withValues(alpha: 0.8)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _FixedYAxisPainter oldDelegate) {
    return oldDelegate.maxY != maxY;
  }
}

class _NavGlassButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _NavGlassButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.74)
              : Colors.white.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        ),
        child: Icon(
          icon,
          size: 17,
          color: enabled ? const Color(0xFF0B2B2B) : const Color(0xFF779392),
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  final String text;

  const _StateChip({required this.text});

  Color _bgFor(String v) {
    final key = v.toLowerCase().replaceAll(' ', '_');
    if (key.contains('cancelado')) return const Color(0xFFFFD8D8);
    if (key.contains('completado')) return const Color(0xFFD9E8FF);
    if (key.contains('en_ruta')) return const Color(0xFFD8FBF3);
    if (key.contains('confirmado')) return const Color(0xFFE1F9E9);
    return const Color(0xFFEAF1F1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _bgFor(text),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0B2B2B),
        ),
      ),
    );
  }
}

class _ServiceSummaryItem {
  final String company;
  final String operator;
  final String status;

  const _ServiceSummaryItem({
    required this.company,
    required this.operator,
    required this.status,
  });
}
