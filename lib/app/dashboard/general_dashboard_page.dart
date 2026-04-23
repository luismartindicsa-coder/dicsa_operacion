import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../hr/human_resources_mock_page.dart';
import '../maintenance/maintenance_page.dart';
import '../mayoreo/mayoreo_cash_entries_exits_page.dart';
import '../mayoreo/mayoreo_dashboard_preview_page.dart';
import '../menudeo/menudeo_dashboard_page.dart';
import '../services/inventory_page.dart';
import '../services/services_catalog_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import 'dashboard_page.dart';

const double _kGeneralDashboardTitleMinWidth = 440;

class GeneralDashboardPage extends StatefulWidget {
  final bool instantOpen;

  const GeneralDashboardPage({super.key, this.instantOpen = false});

  @override
  State<GeneralDashboardPage> createState() => _GeneralDashboardPageState();
}

class _GeneralDashboardPageState extends State<GeneralDashboardPage> {
  bool _canOpenCatalogs = false;
  bool _dashboardsExpanded = true;
  bool _catalogsExpanded = false;
  bool _menuOverlayOpen = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveAccess());
  }

  Future<void> _resolveAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canOpenCatalogs = AuthAccess.canOpenCatalogs(profile);
    });
  }

  Future<void> _logout() async {
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
    if (ok != true || !mounted) return;
    await signOutAndRouteToLogin(context);
  }

  Future<void> _openOperationalDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const DashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openRetailDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openMayoreoPreviewDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MayoreoDashboardPreviewPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openMayoreoCashWorkspace() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MayoreoCashEntriesExitsPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openHumanResourcesMock() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const HumanResourcesMockPage(),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openOperationalEntriesAndOutputs() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const InventoryPage(), fade: false));
  }

  Future<void> _openOperationalInventory() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const InventoryStockPage(), fade: false));
  }

  Future<void> _openOperationalMaintenance() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const MaintenancePage(), fade: false));
  }

  Future<void> _openCatalogsFleet() async {
    if (!mounted || !_canOpenCatalogs) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.26),
      builder: (_) =>
          const ServicesCatalogPage(module: OperationsCatalogModule.flotilla),
    );
  }

  Future<void> _openCatalogsCompanies() async {
    if (!mounted || !_canOpenCatalogs) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.26),
      builder: (_) =>
          const ServicesCatalogPage(module: OperationsCatalogModule.empresas),
    );
  }

  Future<void> _openCatalogsMaterials() async {
    if (!mounted || !_canOpenCatalogs) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.26),
      builder: (_) =>
          const ServicesCatalogPage(module: OperationsCatalogModule.materiales),
    );
  }

  Future<void> _showUpcomingArea(String area) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$area estará disponible en el siguiente dashboard.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        background: const _GeneralDashboardBackground(),
        wrapBodyInGlass: false,
        animateHeaderSlots: false,
        animateBody: !widget.instantOpen,
        headerBodySpacing: 6,
        padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
        leadingBuilder: (_, _) => Row(
          children: [
            _GeneralHeaderButton(
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
            _GeneralDashboardBrand(contentAnim: contentAnim),
        trailingBuilder: (_, _) => _GeneralHeaderButton(
          label: 'Cerrar sesión',
          icon: Icons.logout_rounded,
          onTap: _logout,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 8, 8),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final menu = _GeneralDashboardSideMenu(
      dashboardsExpanded: _dashboardsExpanded,
      catalogsExpanded: _catalogsExpanded,
      canOpenCatalogs: _canOpenCatalogs,
      onOpenGeneralDashboard: () async {},
      onOpenOperationalDashboard: _openOperationalDashboard,
      onOpenMenudeo: _openRetailDashboard,
      onOpenMayoreo: _openMayoreoPreviewDashboard,
      onOpenMayoreoCashWorkspace: _openMayoreoCashWorkspace,
      onOpenHumanResources: _openHumanResourcesMock,
      onOpenAdministration: () => _showUpcomingArea('Administración'),
      onOpenFinance: () => _showUpcomingArea('Finanzas'),
      onOpenAccounting: () => _showUpcomingArea('Contabilidad'),
      onOpenCatalogsFleet: _canOpenCatalogs ? _openCatalogsFleet : null,
      onOpenCatalogsCompanies: _canOpenCatalogs ? _openCatalogsCompanies : null,
      onOpenCatalogsMaterials: _canOpenCatalogs ? _openCatalogsMaterials : null,
      onToggleDashboardsExpanded: () =>
          setState(() => _dashboardsExpanded = !_dashboardsExpanded),
      onToggleCatalogsExpanded: _canOpenCatalogs
          ? () => setState(() => _catalogsExpanded = !_catalogsExpanded)
          : null,
    );

    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 56, right: 2, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ExecutiveOverviewHero(),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1180;
                  final medium = constraints.maxWidth >= 860;
                  final summaryWidth = wide
                      ? (constraints.maxWidth - 32) / 3
                      : (medium
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth);
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _AreaSummaryCard(
                        width: summaryWidth,
                        accent: const Color(0xFF0B2B2B),
                        icon: Icons.precision_manufacturing_rounded,
                        title: 'Operación',
                        status: 'Activo',
                        statusColor: const Color(0xFF1E8E63),
                        description:
                            'Resumen operativo del patio, inventario, servicios, mantenimiento y almacén.',
                        highlights: const [
                          'Inventario, entradas y producción',
                          'Servicios, pesadas y mantenimiento',
                          'Listo para abrir el dashboard operativo',
                        ],
                        primaryLabel: 'Abrir dashboard',
                        onPrimaryTap: _openOperationalDashboard,
                        secondaryLabel: 'Ver inventario',
                        onSecondaryTap: _openOperationalInventory,
                      ),
                      _AreaSummaryCard(
                        width: summaryWidth,
                        accent: const Color(0xFF8E3F2A),
                        icon: Icons.storefront_rounded,
                        title: 'Menudeo',
                        status: 'Activo',
                        statusColor: const Color(0xFFB85637),
                        description:
                            'Operación comercial de compras, ventas, caja, conciliación y catálogo de precios.',
                        highlights: const [
                          'Compras, ventas y vouchers de caja',
                          'Ajustes de precios y catálogo operativo',
                          'Listo para abrir el dashboard de Menudeo',
                        ],
                        primaryLabel: 'Abrir dashboard',
                        onPrimaryTap: _openRetailDashboard,
                      ),
                      _AreaSummaryCard(
                        width: summaryWidth,
                        accent: const Color(0xFF8C6700),
                        icon: Icons.inventory_2_rounded,
                        title: 'Mayoreo',
                        status: 'Preview',
                        statusColor: const Color(0xFFC59517),
                        description:
                            'Sandbox inicial para validar la paleta amarilla y el ritmo visual del futuro dashboard comercial mayorista.',
                        highlights: const [
                          'Paleta amarilla institucional del área',
                          'Prueba de contraste, glow, badges y widgets',
                          'Listo para abrir el preview de dashboard',
                        ],
                        primaryLabel: 'Abrir preview',
                        onPrimaryTap: _openMayoreoPreviewDashboard,
                      ),
                      _AreaSummaryCard(
                        width: summaryWidth,
                        accent: const Color(0xFF6A3B10),
                        icon: Icons.groups_2_rounded,
                        title: 'Recursos humanos',
                        status: 'Mock listo',
                        statusColor: const Color(0xFF7A4AF0),
                        description:
                            'Asistencia, plantilla, incidencias y seguimiento del personal.',
                        highlights: const [
                          'Indicadores de headcount',
                          'Ausentismo y rotación',
                          'Mock visual navegable disponible',
                        ],
                        primaryLabel: 'Abrir mock',
                        onPrimaryTap: _openHumanResourcesMock,
                      ),
                      _AreaSummaryCard(
                        width: summaryWidth,
                        accent: const Color(0xFF244F74),
                        icon: Icons.apartment_rounded,
                        title: 'Administración',
                        status: 'Próximamente',
                        statusColor: const Color(0xFF3B7DB4),
                        description:
                            'Contratos, control documental, compras y seguimiento administrativo.',
                        highlights: const [
                          'Control documental central',
                          'Compras y aprobaciones',
                          'Pendiente de construcción',
                        ],
                        primaryLabel: 'Preparar área',
                        onPrimaryTap: () => _showUpcomingArea('Administración'),
                      ),
                      _AreaSummaryCard(
                        width: summaryWidth,
                        accent: const Color(0xFF195A47),
                        icon: Icons.payments_rounded,
                        title: 'Finanzas',
                        status: 'Próximamente',
                        statusColor: const Color(0xFF1E8E63),
                        description:
                            'Flujo, tesorería, proyecciones y visibilidad ejecutiva de resultados.',
                        highlights: const [
                          'Caja y tesorería',
                          'KPIs de liquidez',
                          'Pendiente de construcción',
                        ],
                        primaryLabel: 'Preparar área',
                        onPrimaryTap: () => _showUpcomingArea('Finanzas'),
                      ),
                      _AreaSummaryCard(
                        width: summaryWidth,
                        accent: const Color(0xFF5C1E3B),
                        icon: Icons.receipt_long_rounded,
                        title: 'Contabilidad',
                        status: 'Próximamente',
                        statusColor: const Color(0xFFC25A7C),
                        description:
                            'Pólizas, cierres, conciliaciones y trazabilidad contable por periodo.',
                        highlights: const [
                          'Cierres contables',
                          'Conciliaciones y pólizas',
                          'Pendiente de construcción',
                        ],
                        primaryLabel: 'Preparar área',
                        onPrimaryTap: () => _showUpcomingArea('Contabilidad'),
                      ),
                      _AreaSummaryCard(
                        width: summaryWidth,
                        accent: const Color(0xFF3A3A3A),
                        icon: Icons.hub_rounded,
                        title: 'Accesos rápidos',
                        status: 'Disponible',
                        statusColor: const Color(0xFF2459A6),
                        description:
                            'Puente inicial entre Dirección, dashboard operativo y catálogos base.',
                        highlights: const [
                          'Entradas y salidas',
                          'Mantenimiento operativo',
                          'Catálogos maestros',
                        ],
                        primaryLabel: 'Entradas y salidas',
                        onPrimaryTap: _openOperationalEntriesAndOutputs,
                        secondaryLabel: 'Mantenimiento',
                        onSecondaryTap: _openOperationalMaintenance,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    const overlayWidth = 320.0;

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
}

class _ExecutiveOverviewHero extends StatelessWidget {
  const _ExecutiveOverviewHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7FCFF), Color(0xFFE7FFF5), Color(0xFFFFF7E8)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            blurRadius: 32,
            offset: const Offset(0, 18),
            color: Colors.black.withValues(alpha: 0.10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 1024;
          final metricWidth = stacked
              ? constraints.maxWidth
              : (constraints.maxWidth - 32) / 3;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2B2B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: DicsaLogoD(size: 46, progress: 1.0),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 780),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vista general de Dirección',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0B2B2B),
                            height: 1.0,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Este dashboard centraliza el resumen de todas las áreas de la empresa y funciona como puerta de entrada para navegar entre dashboards ejecutivos y catálogos maestros.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF355454),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: metricWidth,
                    child: const _HeroMetricChip(
                      label: 'Áreas resumidas',
                      value: '5',
                      subtitle:
                          'Operación, RH, Administración, Finanzas y Contabilidad',
                    ),
                  ),
                  SizedBox(
                    width: metricWidth,
                    child: const _HeroMetricChip(
                      label: 'Dashboard activo',
                      value: 'Dirección',
                      subtitle:
                          'Operación disponible hoy; otras áreas entran después',
                    ),
                  ),
                  SizedBox(
                    width: metricWidth,
                    child: const _HeroMetricChip(
                      label: 'Navegación',
                      value: 'Dashboards + catálogos',
                      subtitle:
                          'Menú lateral orientado a exploración ejecutiva',
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;

  const _HeroMetricChip({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.84)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: Color(0xFF557575),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0B2B2B),
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF486666),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaSummaryCard extends StatelessWidget {
  final double width;
  final Color accent;
  final IconData icon;
  final String title;
  final String status;
  final Color statusColor;
  final String description;
  final List<String> highlights;
  final String primaryLabel;
  final Future<void> Function() onPrimaryTap;
  final String? secondaryLabel;
  final Future<void> Function()? onSecondaryTap;

  const _AreaSummaryCard({
    required this.width,
    required this.accent,
    required this.icon,
    required this.title,
    required this.status,
    required this.statusColor,
    required this.description,
    required this.highlights,
    required this.primaryLabel,
    required this.onPrimaryTap,
    this.secondaryLabel,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            offset: const Offset(0, 16),
            color: accent.withValues(alpha: 0.10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0B2B2B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: Color(0xFF4C6666),
            ),
          ),
          const SizedBox(height: 16),
          ...highlights.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF203434),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onPrimaryTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(primaryLabel),
                ),
              ),
              if (secondaryLabel != null && onSecondaryTap != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSecondaryTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: accent.withValues(alpha: 0.38)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(secondaryLabel!),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _GeneralDashboardBrand extends StatelessWidget {
  final Animation<double> contentAnim;

  const _GeneralDashboardBrand({required this.contentAnim});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showTitle =
            constraints.maxWidth >= _kGeneralDashboardTitleMinWidth;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
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
                      'Dashboard Dirección',
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

class _GeneralHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;

  const _GeneralHeaderButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_GeneralHeaderButton> createState() => _GeneralHeaderButtonState();
}

class _GeneralHeaderButtonState extends State<_GeneralHeaderButton> {
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

class _GeneralDashboardBackground extends StatelessWidget {
  const _GeneralDashboardBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF3D7), Color(0xFFF1F7FF), Color(0xFFE4FFF2)],
            ),
          ),
        ),
        Positioned(
          left: -260,
          top: -120,
          child: _blurCircle(
            760,
            const LinearGradient(
              colors: [Color(0xFFFFD597), Color(0xFFFFF8DD)],
            ),
          ),
        ),
        Positioned(
          right: -200,
          top: -60,
          child: _blurCircle(
            620,
            const LinearGradient(
              colors: [Color(0xFF9ED4FF), Color(0xFFEAF6FF)],
            ),
          ),
        ),
        Positioned(
          left: 80,
          bottom: -240,
          child: _blurCircle(
            580,
            const LinearGradient(
              colors: [Color(0xFFB8F0D0), Color(0xFFEFFFF7)],
            ),
          ),
        ),
        Positioned(
          right: -80,
          bottom: -130,
          child: Container(
            width: 320,
            height: 460,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(220),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0B2B2B), Color(0xFFD99532)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _blurCircle(double size, Gradient gradient) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
    );
  }
}

class _GeneralDashboardSideMenu extends StatelessWidget {
  final bool dashboardsExpanded;
  final bool catalogsExpanded;
  final bool canOpenCatalogs;
  final VoidCallback? onToggleDashboardsExpanded;
  final VoidCallback? onToggleCatalogsExpanded;
  final Future<void> Function()? onOpenGeneralDashboard;
  final Future<void> Function()? onOpenOperationalDashboard;
  final Future<void> Function()? onOpenMenudeo;
  final Future<void> Function()? onOpenMayoreo;
  final Future<void> Function()? onOpenMayoreoCashWorkspace;
  final Future<void> Function()? onOpenHumanResources;
  final Future<void> Function()? onOpenAdministration;
  final Future<void> Function()? onOpenFinance;
  final Future<void> Function()? onOpenAccounting;
  final Future<void> Function()? onOpenCatalogsFleet;
  final Future<void> Function()? onOpenCatalogsCompanies;
  final Future<void> Function()? onOpenCatalogsMaterials;

  const _GeneralDashboardSideMenu({
    required this.dashboardsExpanded,
    required this.catalogsExpanded,
    required this.canOpenCatalogs,
    this.onToggleDashboardsExpanded,
    this.onToggleCatalogsExpanded,
    this.onOpenGeneralDashboard,
    this.onOpenOperationalDashboard,
    this.onOpenMenudeo,
    this.onOpenMayoreo,
    this.onOpenMayoreoCashWorkspace,
    this.onOpenHumanResources,
    this.onOpenAdministration,
    this.onOpenFinance,
    this.onOpenAccounting,
    this.onOpenCatalogsFleet,
    this.onOpenCatalogsCompanies,
    this.onOpenCatalogsMaterials,
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mapa ejecutivo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Dashboards y catálogos',
                style: TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 14),
                _MenuBlock(
                  icon: Icons.space_dashboard_rounded,
                  title: 'Dashboards',
                  expanded: dashboardsExpanded,
                  onToggle: onToggleDashboardsExpanded,
                  children: [
                    _MenuActionItem(
                      icon: Icons.home_work_rounded,
                      title: 'Dirección general',
                      subtitle: 'Resumen ejecutivo multiarea',
                      current: true,
                      onTap: onOpenGeneralDashboard,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.precision_manufacturing_rounded,
                      title: 'Operación',
                      subtitle: 'Dashboard operativo actual',
                      onTap: onOpenOperationalDashboard,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.storefront_rounded,
                      title: 'Menudeo',
                      subtitle: 'Dashboard comercial del área',
                      onTap: onOpenMenudeo,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.inventory_2_rounded,
                      title: 'Mayoreo',
                      subtitle: 'Preview de paleta y tokens',
                      onTap: onOpenMayoreo,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Mayoreo efectivo',
                      subtitle: 'Subpágina resguardada de Dirección',
                      onTap: onOpenMayoreoCashWorkspace,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.groups_2_rounded,
                      title: 'Recursos humanos',
                      subtitle: 'Próximo dashboard',
                      onTap: onOpenHumanResources,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.apartment_rounded,
                      title: 'Administración',
                      subtitle: 'Próximo dashboard',
                      onTap: onOpenAdministration,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.payments_rounded,
                      title: 'Finanzas',
                      subtitle: 'Próximo dashboard',
                      onTap: onOpenFinance,
                    ),
                    const SizedBox(height: 8),
                    _MenuActionItem(
                      icon: Icons.receipt_long_rounded,
                      title: 'Contabilidad',
                      subtitle: 'Próximo dashboard',
                      onTap: onOpenAccounting,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (canOpenCatalogs)
                  _MenuBlock(
                    icon: Icons.library_books_rounded,
                    title: 'Catálogos',
                    expanded: catalogsExpanded,
                    onToggle: onToggleCatalogsExpanded,
                    children: [
                      _MenuActionItem(
                        icon: Icons.badge_outlined,
                        title: 'Flotilla',
                        subtitle: 'Choferes y unidades',
                        onTap: onOpenCatalogsFleet,
                      ),
                      const SizedBox(height: 8),
                      _MenuActionItem(
                        icon: Icons.business_outlined,
                        title: 'Empresas',
                        subtitle: 'Empresas y razones sociales',
                        onTap: onOpenCatalogsCompanies,
                      ),
                      const SizedBox(height: 8),
                      _MenuActionItem(
                        icon: Icons.category_outlined,
                        title: 'Materiales',
                        subtitle: 'General, comercial y operativo',
                        onTap: onOpenCatalogsMaterials,
                      ),
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

class _MenuBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool expanded;
  final VoidCallback? onToggle;
  final List<Widget> children;

  const _MenuBlock({
    required this.icon,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

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
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 160),
                    turns: expanded ? 0.25 : 0.0,
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
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _MenuActionItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool current;
  final Future<void> Function()? onTap;

  const _MenuActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.current = false,
    required this.onTap,
  });

  @override
  State<_MenuActionItem> createState() => _MenuActionItemState();
}

class _MenuActionItemState extends State<_MenuActionItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final highlighted = enabled && (_hovered || widget.current);
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
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.current
                  ? const Color(0xFFFFD27A)
                  : Colors.white.withValues(alpha: 0.18),
            ),
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
              if (widget.current)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: Color(0xFFFFD27A),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
