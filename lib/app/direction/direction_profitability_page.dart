import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'direction_shipments_page.dart';
import 'profitability/profitability_view.dart';
import 'direction_projection_page.dart';
import 'direction_theme.dart';

/// GeneralDashboard shell/glass and overlay navigation; simple account statement.
/// Auxiliary detail uses the Mantenimiento archetype and silent refresh.
class DirectionProfitabilityPage extends StatefulWidget {
  final bool instantOpen;
  const DirectionProfitabilityPage({super.key, this.instantOpen = false});
  @override
  State<DirectionProfitabilityPage> createState() =>
      _DirectionProfitabilityPageState();
}

class _DirectionProfitabilityPageState
    extends State<DirectionProfitabilityPage> {
  bool _menuOpen = false;
  Future<void> _openDashboard() async => Navigator.of(context).pushReplacement(
    appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
  );
  Future<void> _openShipments() async => Navigator.of(context).pushReplacement(
    appPageRoute(page: DirectionShipmentsPage(instantOpen: true)),
  );
  @override
  Widget build(BuildContext context) => AreaThemeScope(
    tokens: directionAreaTokens,
    child: Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            _menuOpen) {
          setState(() => _menuOpen = false);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AppShell(
        background: const DirectionExecutiveBackground(),
        wrapBodyInGlass: false,
        animateHeaderSlots: false,
        animateBody: !widget.instantOpen,
        headerBodySpacing: 8,
        padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
        leadingBuilder: (_, _) => DirectionHeaderButton(
          label: _menuOpen ? 'Cerrar panel' : 'Navegación',
          icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
          onTapSync: () => setState(() => _menuOpen = !_menuOpen),
        ),
        centerBuilder: (_, animation) =>
            DirectionHeaderBrand(contentAnim: animation, title: 'Rentabilidad'),
        trailingBuilder: (_, _) => DirectionHeaderButton(
          label: 'Dashboard',
          icon: Icons.space_dashboard_rounded,
          onTap: _openDashboard,
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1460),
                child: Padding(
                  padding: const EdgeInsets.only(left: 56, right: 4),
                  child: const ProfitabilityView(),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: _menuOpen ? 0 : -332,
              top: 0,
              width: 320,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !_menuOpen,
                child: SingleChildScrollView(
                  child: DirectionModuleMenuPanel(
                    entries: [
                      DirectionModuleMenuEntry(
                        icon: Icons.space_dashboard_rounded,
                        title: 'Dashboard Dirección',
                        subtitle: 'Resumen ejecutivo principal',
                        onTap: _openDashboard,
                      ),
                      DirectionModuleMenuEntry(
                        icon: Icons.local_shipping_rounded,
                        title: 'Embarques',
                        subtitle: 'Embarques y programa operativo',
                        onTap: _openShipments,
                      ),
                      DirectionModuleMenuEntry(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Proyección',
                        subtitle: 'Ingresos, egresos y flujo semanal',
                        onTap: () async =>
                            Navigator.of(context).pushReplacement(
                              appPageRoute(
                                page: const DirectionProjectionPage(
                                  instantOpen: true,
                                ),
                              ),
                            ),
                      ),
                      const DirectionModuleMenuEntry(
                        icon: Icons.business_center_outlined,
                        title: 'Rentabilidad por empresa',
                        subtitle: 'Material, costos y contribución',
                        current: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
