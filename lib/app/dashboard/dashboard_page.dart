import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/inventory_page.dart';
import '../services/services_catalog_page.dart';
import '../services/services_page.dart';
import '../shared/app_shell.dart';
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
  bool _canOpenCatalogs = false;
  bool _sideMenuCollapsed = false;
  bool _catalogsExpanded = false;
  bool _menuOverlayOpen = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveCatalogAccess());
  }

  Future<void> _resolveCatalogAccess() async {
    final supa = Supabase.instance.client;
    final user = supa.auth.currentUser;
    if (user == null) return;

    final email = (user.email ?? '').toLowerCase().trim();
    if (email == 'operacion@dicsamx.com') {
      if (mounted) setState(() => _canOpenCatalogs = true);
      return;
    }

    try {
      final row = await supa
          .from('profiles')
          .select('role, is_active')
          .eq('user_id', user.id)
          .maybeSingle();
      final isActive = (row?['is_active'] as bool?) ?? true;
      final role = ((row?['role'] as String?) ?? '').toLowerCase().trim();
      if (!mounted) return;
      setState(() => _canOpenCatalogs = isActive && role == 'ops_manager');
    } catch (_) {
      if (!mounted) return;
      setState(() => _canOpenCatalogs = false);
    }
  }

  Future<void> _openCatalogsFleet() async {
    if (!mounted) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.26),
      builder: (_) =>
          const ServicesCatalogPage(module: OperationsCatalogModule.flotilla),
    );
  }

  Future<void> _openCatalogsCompanies() async {
    if (!mounted) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.26),
      builder: (_) =>
          const ServicesCatalogPage(module: OperationsCatalogModule.empresas),
    );
  }

  Future<void> _openCatalogsMaterials() async {
    if (!mounted) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.26),
      builder: (_) =>
          const ServicesCatalogPage(module: OperationsCatalogModule.materiales),
    );
  }

  Future<void> _openInventoryMovements() async {
    if (!mounted) return;
    await Navigator.of(context).push(appPageRoute(page: const InventoryPage()));
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
    await Supabase.instance.client.auth.signOut();
    // AuthGate te regresa a Login
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      background: const _DashboardBackground(),
      wrapBodyInGlass: false,
      animateHeaderSlots: false,
      animateBody: !widget.instantOpen,
      headerBodySpacing: 6,
      padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
      leadingBuilder: (_, __) => Row(
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
      trailingBuilder: (_, __) => _HeaderIconButton(
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
    );
  }

  Widget _buildDashboardBody(bool stacked) {
    final menu = _DashboardSideMenu(
      collapsed: _sideMenuCollapsed,
      onOpenInventoryMovements: _openInventoryMovements,
      onOpenInventoryProduction: _openInventoryProduction,
      onOpenInventoryStock: _openInventoryStock,
      onOpenServices: _openServices,
      catalogsExpanded: _catalogsExpanded,
      onToggleCatalogsExpanded: _canOpenCatalogs
          ? () => setState(() => _catalogsExpanded = !_catalogsExpanded)
          : null,
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
        final servicesPanelHeight = isWide
            ? _kWidgetGiantHeight
            : (constraints.maxHeight * 0.34).clamp(300.0, 420.0).toDouble();
        const layoutGap = 12.0;
        const horizontalPadding = 56.0 + 2.0;
        final availableWidth = (constraints.maxWidth - horizontalPadding).clamp(
          0.0,
          constraints.maxWidth,
        );
        final resolvedServicesWidth = (availableWidth * 0.28).clamp(
          320.0,
          420.0,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 8, left: 56, right: 2),
          child: isWide
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(child: _InventoryYardPanel()),
                        const SizedBox(width: layoutGap),
                        SizedBox(
                          width: resolvedServicesWidth,
                          height: servicesPanelHeight,
                          child: _AnimatedDashboardSummaryPanel(
                            alignTopLeft: false,
                            maxPanelWidth: resolvedServicesWidth,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _InventoryYardPanel(),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: servicesPanelHeight,
                      child: _AnimatedDashboardSummaryPanel(
                        alignTopLeft: false,
                        maxPanelWidth: constraints.maxWidth,
                      ),
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
                    color: Colors.white.withOpacity(0.24),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.44)),
                  ),
                  child: const Center(
                    child: Hero(
                      tag: 'dicsa_d',
                      child: DicsaLogoD(size: 52, progress: 1.0),
                    ),
                  ),
                ),
                if (showTitle) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2B2B).withOpacity(0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Resumen Operativo',
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
                  ? Colors.white.withOpacity(0.24)
                  : Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: enabled
                    ? Colors.white.withOpacity(0.64)
                    : Colors.white.withOpacity(0.32),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: highlighted ? 30 : 18,
                  color: Colors.black.withOpacity(
                    enabled ? (highlighted ? 0.24 : 0.11) : 0.05,
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
  final bool collapsed;
  final Future<void> Function() onOpenInventoryMovements;
  final Future<void> Function() onOpenInventoryProduction;
  final Future<void> Function() onOpenInventoryStock;
  final Future<void> Function() onOpenServices;
  final bool catalogsExpanded;
  final VoidCallback? onToggleCatalogsExpanded;
  final Future<void> Function()? onOpenCatalogsFleet;
  final Future<void> Function()? onOpenCatalogsCompanies;
  final Future<void> Function()? onOpenCatalogsMaterials;
  final VoidCallback? onToggleCollapsed;

  const _DashboardSideMenu({
    required this.collapsed,
    required this.onOpenInventoryMovements,
    required this.onOpenInventoryProduction,
    required this.onOpenInventoryStock,
    required this.onOpenServices,
    required this.catalogsExpanded,
    this.onToggleCatalogsExpanded,
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
        border: Border.all(color: Colors.white.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            color: Colors.black.withOpacity(0.20),
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
                      const _SideMenuSectionHeader(text: 'Módulos'),
                      const SizedBox(height: 8),
                      _SideMenuModuleGroup(
                        icon: Icons.factory_outlined,
                        title: 'Operación',
                        children: [
                          _SideMenuActionItem(
                            icon: Icons.compare_arrows_rounded,
                            title: 'Entradas y Salidas',
                            subtitle: 'Captura de movimientos IN / OUT',
                            onTap: onOpenInventoryMovements,
                          ),
                          const SizedBox(height: 8),
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
                            icon: Icons.local_shipping_outlined,
                            title: 'Viajes y Servicios',
                            subtitle: 'Programación y captura operativa',
                            onTap: onOpenServices,
                          ),
                          if (onOpenCatalogsFleet != null ||
                              onOpenCatalogsCompanies != null ||
                              onOpenCatalogsMaterials != null) ...[
                            const SizedBox(height: 8),
                            _SideMenuExpandableActionItem(
                              icon: Icons.library_add_outlined,
                              title: 'Catálogos',
                              subtitle: 'Flotilla, empresas y materiales',
                              expanded: catalogsExpanded,
                              onTap: onToggleCatalogsExpanded,
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: catalogsExpanded
                                  ? Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        8,
                                        0,
                                        0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
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
                                              subtitle:
                                                  'General / Comercial / Operativo',
                                              onTap: onOpenCatalogsMaterials,
                                            ),
                                          if (onOpenCatalogsMaterials != null)
                                            const SizedBox(height: 6),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SideMenuExpandableActionItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback? onTap;

  const _SideMenuExpandableActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onTap,
  });

  @override
  State<_SideMenuExpandableActionItem> createState() =>
      _SideMenuExpandableActionItemState();
}

class _SideMenuExpandableActionItemState
    extends State<_SideMenuExpandableActionItem> {
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
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: highlighted
                ? Colors.white.withOpacity(0.14)
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
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
              AnimatedRotation(
                duration: const Duration(milliseconds: 160),
                turns: widget.expanded ? 0.25 : 0.0,
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
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
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
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

class _SideMenuSectionHeader extends StatelessWidget {
  final String text;
  const _SideMenuSectionHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: Color(0xCCFFFFFF),
        ),
      ),
    );
  }
}

class _SideMenuModuleGroup extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SideMenuModuleGroup({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
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
                ? Colors.white.withOpacity(0.14)
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      blurRadius: 18,
                      color: Colors.black.withOpacity(0.08),
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

  const _AnimatedDashboardSummaryPanel({
    this.alignTopLeft = false,
    this.maxPanelWidth = 920,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: maxPanelWidth),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, animatedMaxWidth, child) {
        final panel = _ServicesSummaryPanel(maxWidth: animatedMaxWidth);
        if (!alignTopLeft) return panel;
        return Align(alignment: Alignment.topLeft, child: panel);
      },
    );
  }
}

class _ServicesSummaryPanel extends StatefulWidget {
  final double maxWidth;

  const _ServicesSummaryPanel({this.maxWidth = 920});

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
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.56),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.60)),
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
                  onTap: _prevDate == null ? null : () => _goToDate(_prevDate!),
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
                  onTap: _nextDate == null ? null : () => _goToDate(_nextDate!),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.42),
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
                separatorBuilder: (_, __) => const SizedBox(height: 5),
                itemBuilder: (_, i) {
                  final item = _items[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.72)),
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
                        Expanded(flex: 2, child: _StateChip(text: item.status)),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: null,
              style: FilledButton.styleFrom(
                disabledBackgroundColor: Colors.white.withOpacity(0.36),
                disabledForegroundColor: const Color(
                  0xFF2A4B49,
                ).withOpacity(0.72),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.send_outlined),
              label: const Text(
                'Enviar (Próximamente)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const String _kDashboardInventorySite = 'DICSA_CELAYA';

class _InventoryYardPanel extends StatefulWidget {
  const _InventoryYardPanel();

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
  DateTime _asOfDate = DateUtils.dateOnly(DateTime.now());
  final Map<String, double> _operationalOnHandKg = <String, double>{};
  List<_ProductionLineSeries> _pacaProductionSeries = const [];
  List<_InventoryCommercialBreakdownItem> _scrapBreakdown = const [];
  List<_InventoryCommercialBreakdownItem> _metalBreakdown = const [];
  List<_InventoryCommercialBreakdownItem> _woodBreakdown = const [];
  List<_InventoryCommercialBreakdownItem> _plasticBreakdown = const [];

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
      const Duration(seconds: 15),
      (_) => _requestReload(),
    );

    _realtime?.unsubscribe();
    _realtime = _supa
        .channel('dashboard-yard-inventory')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'movements',
          callback: (_) => _requestReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'opening_balances',
          callback: (_) => _requestReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'production_runs',
          callback: (_) => _requestReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'commercial_material_catalog',
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

  String _sqlMonthStart(DateTime date) =>
      _sqlDate(DateTime(date.year, date.month, 1));

  double _productionBalesFromRow(Map<String, dynamic> row) {
    final direct = _num(
      row['bale_count'] ??
          row['produced_bales'] ??
          row['bales_count'] ??
          row['bales'],
    );
    if (direct > 0) return direct;

    final producedKg = _num(
      row['produced_weight_kg'] ??
          row['produced_kg'] ??
          row['production_kg'] ??
          row['weight_kg'],
    );
    final avgBaleKg = _num(row['avg_bale_weight_kg']);
    if (producedKg > 0 && avgBaleKg > 0) {
      return producedKg / avgBaleKg;
    }
    return 0;
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

  String? _operationalBreakdownGroup(String material) {
    final m = material.trim().toUpperCase();
    if (m == 'SCRAP' || m.contains('CHATARR')) return 'SCRAP';
    if (m == 'METAL' || m.startsWith('METAL_')) return 'METAL';
    if (m == 'WOOD' || m.contains('MADERA')) return 'WOOD';
    if (m == 'PLASTIC' || m.contains('PLAST')) return 'PLASTIC';
    return null;
  }

  Future<void> _reload({bool showLoader = false}) async {
    if (!mounted || _refreshing) return;
    _refreshing = true;
    if (showLoader) {
      setState(() => _loading = true);
    }
    try {
      final asOfDate = DateUtils.dateOnly(DateTime.now());
      final monthStart = DateTime(asOfDate.year, asOfDate.month, 1);
      final trendStart = DateUtils.dateOnly(
        asOfDate.subtract(const Duration(days: 89)),
      );
      final responses = await Future.wait<dynamic>([
        _supa.rpc(
          'rpc_inventory_summary_by_period',
          params: {
            'p_period_month': _sqlMonthStart(asOfDate),
            'p_as_of_date': _sqlDate(asOfDate),
            'p_site': _kDashboardInventorySite,
          },
        ),
        _supa
            .from('commercial_material_catalog')
            .select('code,name')
            .eq('active', true),
        _supa
            .from('opening_balances')
            .select('material,commercial_material_code,weight_kg')
            .eq('site', _kDashboardInventorySite)
            .eq('period_month', _sqlMonthStart(asOfDate)),
        _supa
            .from('movements')
            .select('material,commercial_material_code,flow,weight_kg,op_date')
            .eq('site', _kDashboardInventorySite)
            .gte('op_date', _sqlDate(monthStart))
            .lte('op_date', _sqlDate(asOfDate)),
        _supa
            .from('production_runs')
            .select(
              'op_date,bale_material,bale_count,avg_bale_weight_kg,produced_weight_kg',
            )
            .eq('site', _kDashboardInventorySite)
            .gte('op_date', _sqlDate(trendStart))
            .lte('op_date', _sqlDate(asOfDate)),
      ]);

      final summaryRows = (responses[0] as List).cast<Map<String, dynamic>>();
      final catalogRows = (responses[1] as List).cast<Map<String, dynamic>>();
      final openingRows = (responses[2] as List).cast<Map<String, dynamic>>();
      final movementRows = (responses[3] as List).cast<Map<String, dynamic>>();
      var productionRows = (responses[4] as List).cast<Map<String, dynamic>>();
      if (productionRows.isEmpty) {
        final fallback = await _supa
            .from('production_runs')
            .select(
              'op_date,bale_material,bale_count,avg_bale_weight_kg,produced_weight_kg',
            )
            .gte('op_date', _sqlDate(trendStart))
            .lte('op_date', _sqlDate(asOfDate));
        productionRows = (fallback as List).cast<Map<String, dynamic>>();
      }

      final operational = <String, double>{};
      for (final row in summaryRows) {
        final rawMaterial = (row['material'] ?? '').toString().trim();
        if (rawMaterial.isEmpty) continue;
        final material = _normalizeOperational(rawMaterial);
        operational[material] =
            (operational[material] ?? 0) + _num(row['on_hand_kg']);
      }

      final commercialNames = <String, String>{
        for (final row in catalogRows)
          (row['code'] ?? '').toString(): (row['name'] ?? '').toString(),
      };

      final byMaterialCommercial = <String, double>{};
      final dailyProductionByMaterialAndDate = <String, Map<DateTime, double>>{
        'BALE_NATIONAL': <DateTime, double>{},
        'BALE_AMERICAN': <DateTime, double>{},
        'BALE_CLEAN': <DateTime, double>{},
        'BALE_TRASH': <DateTime, double>{},
      };
      for (final row in openingRows) {
        final rawMaterial = (row['material'] ?? '').toString().trim();
        final code = (row['commercial_material_code'] ?? '').toString().trim();
        if (rawMaterial.isEmpty || code.isEmpty) continue;
        final material = _normalizeOperational(rawMaterial);
        final key = '$material|$code';
        byMaterialCommercial[key] =
            (byMaterialCommercial[key] ?? 0) + _num(row['weight_kg']);
      }

      for (final row in movementRows) {
        final rawMaterial = (row['material'] ?? '').toString().trim();
        final code = (row['commercial_material_code'] ?? '').toString().trim();
        final flow = (row['flow'] ?? '').toString().trim().toUpperCase();
        final signedKg = flow == 'OUT'
            ? -_num(row['weight_kg'])
            : _num(row['weight_kg']);

        if (rawMaterial.isEmpty || code.isEmpty) continue;
        final material = _normalizeOperational(rawMaterial);
        final key = '$material|$code';
        byMaterialCommercial[key] = (byMaterialCommercial[key] ?? 0) + signedKg;
      }

      for (final row in productionRows) {
        final opDate = DateUtils.dateOnly(_parseDate(row['op_date']));
        final producedBales = _productionBalesFromRow(row);
        final material = (row['bale_material'] ?? '').toString().trim();
        final key = dailyProductionByMaterialAndDate.containsKey(material)
            ? material
            : 'BALE_TRASH';
        final perDay = dailyProductionByMaterialAndDate[key]!;
        perDay[opDate] = (perDay[opDate] ?? 0) + producedBales;
      }

      final scrap = <_InventoryCommercialBreakdownItem>[];
      final metal = <_InventoryCommercialBreakdownItem>[];
      final wood = <_InventoryCommercialBreakdownItem>[];
      final plastic = <_InventoryCommercialBreakdownItem>[];

      byMaterialCommercial.forEach((key, kg) {
        if (kg.abs() < 0.005) return;
        final separator = key.indexOf('|');
        if (separator <= 0 || separator >= key.length - 1) return;
        final material = key.substring(0, separator);
        final code = key.substring(separator + 1);
        final name = commercialNames[code] ?? code;
        final item = _InventoryCommercialBreakdownItem(
          code: code,
          name: name,
          kg: kg,
        );
        final group = _operationalBreakdownGroup(material);
        if (group == 'SCRAP') {
          scrap.add(item);
        } else if (group == 'METAL') {
          metal.add(item);
        } else if (group == 'WOOD') {
          wood.add(item);
        } else if (group == 'PLASTIC') {
          plastic.add(item);
        }
      });

      scrap.sort((a, b) => b.kg.compareTo(a.kg));
      metal.sort((a, b) => b.kg.compareTo(a.kg));
      wood.sort((a, b) => b.kg.compareTo(a.kg));
      plastic.sort((a, b) => b.kg.compareTo(a.kg));

      final dayAxis = <DateTime>[];
      for (
        var d = trendStart;
        !d.isAfter(asOfDate);
        d = d.add(const Duration(days: 1))
      ) {
        dayAxis.add(d);
      }
      _ProductionLineSeries buildSeries(
        String material,
        String label,
        Color color,
      ) {
        final perDay = dailyProductionByMaterialAndDate[material]!;
        final points = dayAxis
            .map((d) => _DailyPoint(day: d, value: perDay[d] ?? 0))
            .toList();
        return _ProductionLineSeries(
          label: label,
          color: color,
          points: points,
        );
      }

      final pacaProductionSeries = <_ProductionLineSeries>[
        buildSeries('BALE_NATIONAL', 'Paca nacional', const Color(0xFF1E88E5)),
        buildSeries('BALE_AMERICAN', 'Paca americana', const Color(0xFF43A047)),
        buildSeries('BALE_CLEAN', 'Paca limpia', const Color(0xFFF9A825)),
        buildSeries('BALE_TRASH', 'Paca basura', const Color(0xFFE53935)),
      ];

      if (!mounted) return;
      setState(() {
        _asOfDate = asOfDate;
        _operationalOnHandKg
          ..clear()
          ..addAll(operational);
        _pacaProductionSeries = pacaProductionSeries;
        _scrapBreakdown = scrap;
        _metalBreakdown = metal;
        _woodBreakdown = wood;
        _plasticBreakdown = plastic;
        _loading = false;
      });
    } catch (_) {
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

  String _fmtPacas(double kg) {
    const avgKgPerBale = 850.0;
    final pacas = avgKgPerBale <= 0 ? 0 : (kg / avgKgPerBale);
    return pacas.toStringAsFixed(0);
  }

  String _fmtKg(double value) => '${value.toStringAsFixed(1)} kg';

  @override
  Widget build(BuildContext context) {
    final pacaNacional = _operationalOnHandKg['BALE_NATIONAL'] ?? 0;
    final pacaAmericana = _operationalOnHandKg['BALE_AMERICAN'] ?? 0;
    final pacaLimpia = _operationalOnHandKg['BALE_CLEAN'] ?? 0;
    final pacaBasura = _operationalOnHandKg['BALE_TRASH'] ?? 0;
    final totalPacas = pacaNacional + pacaAmericana + pacaLimpia + pacaBasura;

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
              final tileItems = [
                _SquareTileData(
                  label: 'Pacas patio (est.)',
                  value: '${_fmtPacas(totalPacas)} pacas',
                  secondaryValue: _fmtKg(totalPacas),
                  color: const Color(0xFFD6F4FF),
                ),
                _SquareTileData(
                  label: 'Paca nacional (est.)',
                  value: '${_fmtPacas(pacaNacional)} pacas',
                  secondaryValue: _fmtKg(pacaNacional),
                  color: const Color(0xFFBEEBFF),
                ),
                _SquareTileData(
                  label: 'Paca americana (est.)',
                  value: '${_fmtPacas(pacaAmericana)} pacas',
                  secondaryValue: _fmtKg(pacaAmericana),
                  color: const Color(0xFFC8F7D8),
                ),
                _SquareTileData(
                  label: 'Paca limpia (est.)',
                  value: '${_fmtPacas(pacaLimpia)} pacas',
                  secondaryValue: _fmtKg(pacaLimpia),
                  color: const Color(0xFFFFF4C4),
                ),
                _SquareTileData(
                  label: 'Paca basura (est.)',
                  value: '${_fmtPacas(pacaBasura)} pacas',
                  secondaryValue: _fmtKg(pacaBasura),
                  color: const Color(0xFFFFE2BF),
                ),
                _SquareTileData(
                  label: 'Total pacas hoy',
                  value: '${_fmtPacas(totalPacas)} pacas',
                  secondaryValue: _fmtKg(totalPacas),
                  color: const Color(0xFFE0F3FF),
                ),
              ];
              final tiles = Wrap(
                spacing: gap,
                runSpacing: gap,
                children: tileItems
                    .map((tile) => _SquareTile(tile: tile, width: smallW))
                    .toList(),
              );

              final chart = _ChartCard(
                title: 'Producción diaria de cartón',
                subtitle: 'Comparativo de pacas producidas por día y tipo',
                child: _ProductionBarChart(seriesList: _pacaProductionSeries),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tiles,
                  const SizedBox(height: 10),
                  SizedBox(height: _kWidgetLargeHeight, child: chart),
                  const SizedBox(height: 10),
                  _OperationalBreakdownCard(
                    scrap: _scrapBreakdown,
                    metal: _metalBreakdown,
                    wood: _woodBreakdown,
                    plastic: _plasticBreakdown,
                    mediumCardWidth: mediumW,
                    cardGap: gap,
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

  const _ProductionLineSeries({
    required this.label,
    required this.color,
    required this.points,
  });
}

class _SquareTileData {
  final String label;
  final String value;
  final String? secondaryValue;
  final Color color;

  const _SquareTileData({
    required this.label,
    required this.value,
    this.secondaryValue,
    required this.color,
  });
}

class _SquareTileGrid extends StatelessWidget {
  final List<_SquareTileData> tiles;
  final int? preferredColumns;

  const _SquareTileGrid({required this.tiles, this.preferredColumns});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns =
            preferredColumns ??
            (maxWidth < 760 ? 2 : (maxWidth < 1080 ? 3 : 5));
        final tileWidth = (maxWidth - ((columns - 1) * 8)) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tiles
              .map((tile) => _SquareTile(tile: tile, width: tileWidth))
              .toList(),
        );
      },
    );
  }
}

class _SquareTile extends StatelessWidget {
  final _SquareTileData tile;
  final double width;

  const _SquareTile({required this.tile, required this.width});

  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      child: Container(
        width: width,
        constraints: const BoxConstraints(minHeight: _kWidgetSmallHeight),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.40),
              tile.color.withOpacity(0.56),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.80)),
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
              color: Colors.white.withOpacity(0.34),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
    );
  }
}

class _OperationalBreakdownCard extends StatelessWidget {
  final List<_InventoryCommercialBreakdownItem> scrap;
  final List<_InventoryCommercialBreakdownItem> metal;
  final List<_InventoryCommercialBreakdownItem> wood;
  final List<_InventoryCommercialBreakdownItem> plastic;
  final double? mediumCardWidth;
  final double cardGap;

  const _OperationalBreakdownCard({
    required this.scrap,
    required this.metal,
    required this.wood,
    required this.plastic,
    this.mediumCardWidth,
    this.cardGap = 10,
  });

  String _fmtKg(double value) => '${value.toStringAsFixed(1)} kg';

  @override
  Widget build(BuildContext context) {
    final totalScrap = scrap.fold<double>(0, (sum, item) => sum + item.kg);
    final totalMetal = metal.fold<double>(0, (sum, item) => sum + item.kg);
    final totalWood = wood.fold<double>(0, (sum, item) => sum + item.kg);
    final totalPlastic = plastic.fold<double>(0, (sum, item) => sum + item.kg);
    final totalOp = totalScrap + totalMetal + totalWood + totalPlastic;
    final blocks = <_OperationalBlockData>[
      _OperationalBlockData(
        heading: 'Chatarra',
        accent: const Color(0xFF1F95E0),
        items: scrap,
        totalKg: totalScrap,
      ),
      _OperationalBlockData(
        heading: 'Metal',
        accent: const Color(0xFF7D46D3),
        items: metal,
        totalKg: totalMetal,
      ),
      _OperationalBlockData(
        heading: 'Madera',
        accent: const Color(0xFF9B7A4B),
        items: wood,
        totalKg: totalWood,
      ),
      _OperationalBlockData(
        heading: 'Plástico',
        accent: const Color(0xFF15906F),
        items: plastic,
        totalKg: totalPlastic,
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

  const _OperationalBreakdownTable({
    required this.heading,
    required this.accent,
    required this.items,
    required this.totalKg,
  });

  String _fmtKg(double value) => '${value.toStringAsFixed(1)} kg';

  @override
  Widget build(BuildContext context) {
    final shown = items.take(8).toList();
    return _HoverLift(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.78),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.8)),
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
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.46),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.78)),
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
          ..translate(0.0, _hovered ? -4.0 : 0.0)
          ..scale(_hovered ? 1.008 : 1.0),
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
                                    color: Colors.white.withOpacity(0.95),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _hovered!.color.withOpacity(0.6),
                                    ),
                                  ),
                                  child: Text(
                                    '${_hovered!.label} · ${_hovered!.dayLabel} · ${_hovered!.value.toStringAsFixed(0)} pacas',
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
      ..color = axisColor.withOpacity(0.65)
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
          ..color = axisColor.withOpacity(0.18)
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
        ..color = axisColor.withOpacity(0.75)
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
  final String dayLabel;

  const _HoveredBarInfo({
    required this.dayIndex,
    required this.seriesIndex,
    required this.label,
    required this.color,
    required this.value,
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
          ..color = axisColor.withOpacity(0.7)
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
        ..color = axisColor.withOpacity(0.8)
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
              ? Colors.white.withOpacity(0.74)
              : Colors.white.withOpacity(0.30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.72)),
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
