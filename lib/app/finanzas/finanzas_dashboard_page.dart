import 'package:flutter/material.dart';

import '../auth/auth_access.dart';
import '../compras/compras_dashboard_page.dart';
import '../shared/archetypes/dashboard/empty_area_dashboard.dart';
import '../shared/page_routes.dart';
import 'finanzas_catalog_page.dart';
import 'finanzas_company_directory_page.dart';
import 'finanzas_theme.dart';

class FinanzasDashboardPage extends StatelessWidget {
  final bool instantOpen;

  const FinanzasDashboardPage({super.key, this.instantOpen = false});

  Future<void> _openCompras(BuildContext context) async {
    await Navigator.of(context).push(
      appPageRoute(
        page: const ComprasDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openCatalog(BuildContext context) async {
    await Navigator.of(context).push(
      appPageRoute(
        page: const FinanzasCatalogPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openDirectory(BuildContext context) async {
    await Navigator.of(context).push(
      appPageRoute(
        page: const FinanzasCompanyDirectoryPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EmptyAreaDashboardPage(
      instantOpen: instantOpen,
      config: EmptyAreaDashboardConfig(
        dashboardLabel: 'Dashboard Finanzas',
        sidePanelLabel: 'Finanzas',
        heroEyebrow: 'FINANZAS',
        heroTitle: 'Base homologada para flujo, pagos y liquidez operativa.',
        heroSubtitle:
            'La pantalla arranca vacía para evitar métricas falsas. Dejamos lista la estructura real donde después vivirán facturas, pagos, compromisos y recomendaciones.',
        emptyTitle: 'Dashboard preliminar sin simulaciones',
        emptySubtitle:
            'Aquí conectaremos únicamente información real de facturas, abonos, cuentas, bancos y bóveda cuando el flujo quede definido.',
        contractTitle: 'Contrato base listo',
        contractSubtitle:
            'Finanzas nace como área hermana de Compras con la misma familia visual y el mismo comportamiento de dashboard homologado.',
        contractFootnote:
            'Finanzas invierte la dirección cromática a rojo con negro para conservar parentesco visual con Compras y marcar que es otra responsabilidad.',
        tokens: finanzasAreaTokens,
        ink: kFinanzasInk,
        mutedInk: kFinanzasMutedInk,
        heroGradient: kFinanzasHeroGradient,
        panelGradient: kFinanzasPanelGradient,
        accentGradient: kFinanzasAccentGradient,
        backgroundGradientColors: const [
          Color(0xFFF7E5E2),
          Color(0xFFD45A52),
          Color(0xFF241313),
        ],
        topLeftBlobColors: const [Color(0xFFFFF6F4), Color(0xFFF2C0BC)],
        topRightBlobColors: const [Color(0xFFBC2D25), Color(0x33241313)],
        bottomLeftBlobColors: const [Color(0x66241313), Color(0xFFFBE8E6)],
        pillarGradientColors: const [Color(0xFF241313), Color(0xFFBC2D25)],
        areaItems: [
          DashboardNavAction(
            title: 'Dashboard Finanzas',
            subtitle: 'Pagos, liquidez y compromisos',
            icon: Icons.account_balance_wallet_outlined,
            current: true,
            onTap: () async {},
          ),
          DashboardNavAction(
            title: 'Catálogo Finanzas',
            subtitle: 'Empresas, conceptos y relaciones',
            icon: Icons.price_check_rounded,
            onTap: () => _openCatalog(context),
          ),
          DashboardNavAction(
            title: 'Directorio Empresas',
            subtitle: 'Crédito, contacto y operación',
            icon: Icons.account_balance_rounded,
            onTap: () => _openDirectory(context),
          ),
        ],
        accessItems: [
          DashboardNavAction(
            title: 'Dashboard Compras',
            subtitle: 'Tickets y operación de compra',
            icon: Icons.shopping_cart_checkout_rounded,
            onTap: () => _openCompras(context),
            isVisible: AuthAccess.canAccessComprasArea,
          ),
        ],
        headerActions: [
          DashboardHeaderAction(
            label: 'Catálogo',
            icon: Icons.price_check_rounded,
            onTap: () => _openCatalog(context),
          ),
          DashboardHeaderAction(
            label: 'Directorio',
            icon: Icons.account_balance_rounded,
            onTap: () => _openDirectory(context),
          ),
        ],
      ),
    );
  }
}
