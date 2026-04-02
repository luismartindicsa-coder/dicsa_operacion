import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/confirm_dialog_key_handler.dart';
import 'menudeo_catalog_page.dart';
import 'menudeo_theme.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';

class MenudeoDashboardPage extends StatefulWidget {
  const MenudeoDashboardPage({super.key});

  @override
  State<MenudeoDashboardPage> createState() => _MenudeoDashboardPageState();
}

class _MenudeoDashboardPageState extends State<MenudeoDashboardPage> {
  bool _menuOpen = false;

  Future<void> _goBack() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  void _showStub(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label quedará conectado en la siguiente fase de Menudeo.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openCatalogPage() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(appPageRoute(page: const MenudeoCatalogPage(), fade: false));
  }

  void _handleAreaAction(String label) {
    if (label == 'Contrapartes y precios') {
      unawaited(_openCatalogPage());
      return;
    }
    _showStub(label);
  }

  Future<void> _logout() async {
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
    if (ok != true || !mounted) return;
    await signOutAndRouteToLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: menudeoAreaTokens,
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
          background: const _MenudeoBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          headerBodySpacing: 6,
          padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
          leadingBuilder: (_, anim) => _MenudeoHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Menú',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, contentAnim) =>
              _MenudeoBrand(contentAnim: contentAnim),
          trailingBuilder: (_, anim) => _MenudeoHeaderButton(
            label: 'Cerrar sesión',
            icon: Icons.logout_rounded,
            onTap: _logout,
          ),
          child: Stack(
            children: [
              _MenudeoBody(onStubTap: _handleAreaAction),
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
                  child: _MenudeoSidePanel(
                    onBack: _goBack,
                    onStubTap: _handleAreaAction,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenudeoBody extends StatelessWidget {
  final ValueChanged<String> onStubTap;

  const _MenudeoBody({required this.onStubTap});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 56, right: 2, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MenudeoHero(onStubTap: onStubTap),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 1200
                      ? 4
                      : width >= 860
                      ? 2
                      : 1;
                  final spacing = 16.0;
                  final cardWidth =
                      (width - ((columns - 1) * spacing)) / columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      _MenudeoMetricCard(
                        width: cardWidth,
                        icon: Icons.shopping_basket_rounded,
                        title: 'Compras del día',
                        value: '\$ 186,420',
                        detail: '42 tickets capturados',
                        accent: tokens.primaryStrong,
                      ),
                      _MenudeoMetricCard(
                        width: cardWidth,
                        icon: Icons.point_of_sale_rounded,
                        title: 'Ventas del día',
                        value: '\$ 248,960',
                        detail: '31 tickets conciliables',
                        accent: tokens.accent,
                      ),
                      _MenudeoMetricCard(
                        width: cardWidth,
                        icon: Icons.scale_rounded,
                        title: 'Kg conciliables',
                        value: '128,540 kg',
                        detail: '92.6% ya cruzados',
                        accent: tokens.badgeText,
                      ),
                      _MenudeoMetricCard(
                        width: cardWidth,
                        icon: Icons.warning_amber_rounded,
                        title: 'Pendientes',
                        value: '7 tickets',
                        detail: '2 con diferencia neta',
                        accent: const Color(0xFFC47A18),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 980;
                  if (stacked) {
                    return Column(
                      children: [
                        _MenudeoActionRail(onStubTap: onStubTap),
                        const SizedBox(height: 16),
                        const _MenudeoInsightGrid(),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: math.min(360, constraints.maxWidth * 0.3),
                        child: _MenudeoActionRail(onStubTap: onStubTap),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(child: _MenudeoInsightGrid()),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenudeoHero extends StatelessWidget {
  final ValueChanged<String> onStubTap;

  const _MenudeoHero({required this.onStubTap});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: tokens.badgeBackground,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: tokens.primaryStrong,
                  size: 30,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Menudeo',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: tokens.primaryStrong,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dashboard de prueba para validar paleta, jerarquía visual y tono del área.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tokens.badgeText.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'La intención visual es comercial y ágil, pero sin romper el lenguaje glass ni la estructura fija de DICSA. Aquí después vivirán resúmenes de compras, ventas, conciliación y corte.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: tokens.primaryStrong.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton(
                style: contractPrimaryButtonStyle(context),
                onPressed: () => onStubTap('Contrapartes y precios'),
                child: const Text('Contrapartes y precios'),
              ),
              OutlinedButton(
                style: contractSecondaryButtonStyle(context),
                onPressed: () => onStubTap('Compras menudeo'),
                child: const Text('Compras menudeo'),
              ),
              OutlinedButton(
                style: contractSecondaryButtonStyle(context),
                onPressed: () => onStubTap('Ventas menudeo'),
                child: const Text('Ventas menudeo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenudeoMetricCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final Color accent;

  const _MenudeoMetricCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ContractGlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF5A5552),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F262B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6A6966),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenudeoActionRail extends StatelessWidget {
  final ValueChanged<String> onStubTap;

  const _MenudeoActionRail({required this.onStubTap});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return ContractGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accesos del área',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'La captura y el control deben sentirse inmediatos. Aquí se validará si la paleta se siente correcta en acciones frecuentes.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: tokens.badgeText.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 16),
          ...[
            ('Contrapartes y precios', Icons.price_change_rounded),
            ('Compras menudeo', Icons.add_shopping_cart_rounded),
            ('Ventas menudeo', Icons.sell_rounded),
            ('Conciliación de tickets', Icons.rule_folder_rounded),
            ('Corte de caja', Icons.receipt_long_rounded),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MenudeoActionButton(
                label: item.$1,
                icon: item.$2,
                onTap: () => onStubTap(item.$1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenudeoInsightGrid extends StatelessWidget {
  const _MenudeoInsightGrid();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ContractGlassCard(
                padding: const EdgeInsets.all(18),
                child: _InsightBlock(
                  title: 'Precio promedio de compra',
                  subtitle: 'Cartón, chatarra y metal por grupo comercial',
                  values: const [
                    'Público general: \$4.82',
                    'Triciclos: \$4.65',
                    'Preferenciales: \$5.04',
                  ],
                  accent: tokens.primary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ContractGlassCard(
                padding: const EdgeInsets.all(18),
                child: _InsightBlock(
                  title: 'Estado de conciliación',
                  subtitle: 'Corte preliminar del turno',
                  values: const [
                    'Conciliados exactos: 24',
                    'Con split: 5',
                    'Pendientes de caja: 3',
                  ],
                  accent: tokens.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ContractGlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alertas y observaciones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const [
                  _AlertPill(
                    title: '2 tickets con neto fuera de tolerancia',
                    tone: Color(0xFFB65C2A),
                  ),
                  _AlertPill(
                    title: '3 contrapartes sin precio reciente',
                    tone: Color(0xFFC47A18),
                  ),
                  _AlertPill(
                    title: '1 material capturado por alias temporal',
                    tone: Color(0xFF7A3422),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> values;
  final Color accent;

  const _InsightBlock({
    required this.title,
    required this.subtitle,
    required this.values,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF202629),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF666461),
          ),
        ),
        const SizedBox(height: 14),
        ...values.map(
          (value) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3133),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AlertPill extends StatelessWidget {
  final String title;
  final Color tone;

  const _AlertPill({required this.title, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: tone,
        ),
      ),
    );
  }
}

class _MenudeoSidePanel extends StatelessWidget {
  final Future<void> Function() onBack;
  final ValueChanged<String> onStubTap;

  const _MenudeoSidePanel({required this.onBack, required this.onStubTap});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ContractGlassCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Menudeo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dashboard demo del área',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tokens.badgeText,
                ),
              ),
              const SizedBox(height: 16),
              _MenudeoPanelItem(
                icon: Icons.arrow_back_rounded,
                title: 'Volver a Dirección',
                subtitle: 'Regresar al dashboard general',
                onTap: onBack,
              ),
              const SizedBox(height: 10),
              _MenudeoPanelItem(
                icon: Icons.price_check_rounded,
                title: 'Contrapartes y precios',
                subtitle: 'Superficie consolidada del área',
                onTapSync: () => onStubTap('Contrapartes y precios'),
              ),
              const SizedBox(height: 10),
              _MenudeoPanelItem(
                icon: Icons.receipt_rounded,
                title: 'Tickets',
                subtitle: 'Compras, ventas y corte',
                onTapSync: () => onStubTap('Tickets de menudeo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenudeoPanelItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _MenudeoPanelItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.onTapSync,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          if (onTap != null) {
            await onTap!();
          } else {
            onTapSync?.call();
          }
        },
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tokens.surfaceTint.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.border.withValues(alpha: 0.76)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tokens.badgeBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: tokens.primaryStrong),
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
                        color: tokens.primaryStrong,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF675C57),
                      ),
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

class _MenudeoActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MenudeoActionButton({
    required this.label,
    required this.icon,
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
            color: tokens.surfaceTint.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.border.withValues(alpha: 0.76)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: tokens.primaryStrong),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: tokens.primaryStrong,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenudeoHeaderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _MenudeoHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          if (onTap != null) {
            await onTap!();
          } else {
            onTapSync?.call();
          }
        },
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.46)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: tokens.primaryStrong),
              const SizedBox(width: 10),
              Text(
                label,
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
    );
  }
}

class _MenudeoBrand extends StatelessWidget {
  final Animation<double> contentAnim;

  const _MenudeoBrand({required this.contentAnim});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Opacity(
      opacity: contentAnim.value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: DicsaLogoD(size: 58),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 1,
            height: 48,
            color: tokens.primaryStrong.withValues(alpha: 0.22),
          ),
          const SizedBox(width: 16),
          Text(
            'Dashboard Menudeo',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenudeoBackground extends StatelessWidget {
  const _MenudeoBackground();

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
                tokens.surfaceTint,
                tokens.primarySoft.withValues(alpha: 0.9),
                tokens.accent.withValues(alpha: 0.38),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: -260,
          top: -110,
          child: _blurCircle(
            760,
            LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.92),
                tokens.primarySoft.withValues(alpha: 0.94),
              ],
            ),
          ),
        ),
        Positioned(
          right: -210,
          top: -70,
          child: _blurCircle(
            620,
            LinearGradient(
              colors: [
                tokens.accent.withValues(alpha: 0.82),
                tokens.glow.withValues(alpha: 0.44),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          bottom: -250,
          child: _blurCircle(
            620,
            LinearGradient(
              colors: [
                tokens.primary.withValues(alpha: 0.32),
                tokens.primarySoft.withValues(alpha: 0.92),
              ],
            ),
          ),
        ),
        Positioned(
          right: -110,
          bottom: -120,
          child: Container(
            width: 320,
            height: 500,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(220),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tokens.accent.withValues(alpha: 0.95),
                  tokens.primaryStrong.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _blurCircle(double size, Gradient gradient) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
      ),
    );
  }
}
