import 'package:flutter/material.dart';

import '../finanzas/finanzas_dashboard_page.dart';
import '../shared/archetypes/dashboard/empty_area_dashboard.dart';
import '../shared/page_routes.dart';
import 'compras_catalog_page.dart';
import 'compras_theme.dart';

class ComprasDashboardPage extends StatelessWidget {
  final bool instantOpen;

  const ComprasDashboardPage({super.key, this.instantOpen = false});

  Future<void> _openFinanzas(BuildContext context) async {
    await Navigator.of(context).push(
      appPageRoute(
        page: const FinanzasDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openCatalog(BuildContext context) async {
    await Navigator.of(context).push(
      appPageRoute(
        page: const ComprasCatalogPage(instantOpen: true),
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
        dashboardLabel: 'Dashboard Compras Mayoreo',
        sidePanelLabel: 'Compras Mayoreo',
        headerTitleColor: const Color(0xFFE6DBD8),
        heroEyebrow: 'COMPRAS MAYOREO',
        heroTitle:
            'Base homologada para compras, tickets y seguimiento operativo.',
        heroSubtitle:
            'La superficie queda vacía a propósito para conectar únicamente funcionalidad real. Shell, navegación, hover, cards y widgets ya nacen alineados al contrato.',
        emptyTitle: 'Dashboard preliminar sin mocks',
        emptySubtitle:
            'Aquí iremos conectando tickets, cuentas de compra y vistas reales del área sin inventar KPIs temporales.',
        contractTitle: 'Contrato base listo',
        contractSubtitle:
            'Se clonó la familia visual de Dashboard Ventas Mayoreo y se dejó lista para crecer como área hermana de Finanzas.',
        contractFootnote:
            'Compras usa dirección cromática negra con rojo para compartir fuente visual con Finanzas sin mezclarse como la misma área.',
        tokens: comprasAreaTokens,
        ink: kComprasInk,
        mutedInk: kComprasMutedInk,
        heroGradient: kComprasHeroGradient,
        panelGradient: kComprasPanelGradient,
        accentGradient: kComprasAccentGradient,
        backgroundGradientColors: const [
          Color(0xFF181010),
          Color(0xFF241515),
          Color(0xFF3A2020),
        ],
        topLeftBlobColors: const [Color(0xFF332020), Color(0xFF181010)],
        topRightBlobColors: const [Color(0xFF9C211B), Color(0x33261515)],
        bottomLeftBlobColors: const [Color(0x338F201A), Color(0xFFF0E4E2)],
        pillarGradientColors: const [Color(0xFFAA2A23), Color(0xFF261818)],
        areaItems: [
          DashboardNavAction(
            title: 'Dashboard Compras',
            subtitle: 'Tickets y operación de compra',
            icon: Icons.shopping_cart_checkout_rounded,
            current: true,
            onTap: () async {},
          ),
          DashboardNavAction(
            title: 'Catálogo Compras',
            subtitle: 'Proveedores, materiales y precios',
            icon: Icons.price_check_rounded,
            onTap: () => _openCatalog(context),
          ),
        ],
        accessItems: [
          DashboardNavAction(
            title: 'Dashboard Finanzas',
            subtitle: 'Pagos, liquidez y compromisos',
            icon: Icons.account_balance_wallet_outlined,
            onTap: () => _openFinanzas(context),
          ),
        ],
        headerActions: [
          DashboardHeaderAction(
            label: 'Catálogo',
            icon: Icons.price_check_rounded,
            onTap: () => _openCatalog(context),
          ),
        ],
      ),
    );
  }
}
