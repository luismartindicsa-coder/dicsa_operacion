import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'contabilidad_theme.dart';

class ContabilidadDashboardPage extends StatefulWidget {
  final bool instantOpen;

  const ContabilidadDashboardPage({super.key, this.instantOpen = false});

  @override
  State<ContabilidadDashboardPage> createState() =>
      _ContabilidadDashboardPageState();
}

class _ContabilidadDashboardPageState extends State<ContabilidadDashboardPage> {
  bool _menuOpen = false;

  Future<void> _logout() => signOutAndRouteToLogin(context);

  Future<void> _openDirectionDashboard() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sidePanelItems = <ContabilidadSidePanelItem>[
      const ContabilidadSidePanelItem(
        icon: Icons.account_balance_rounded,
        title: 'Dashboard Contabilidad',
        subtitle: 'Consolidado general del area',
        current: true,
      ),
      ContabilidadSidePanelItem(
        icon: Icons.swap_horiz_rounded,
        title: 'Balance Compra-Venta',
        subtitle: 'Lectura comercial comparativa',
        onTap: _openDirectionDashboard,
      ),
      const ContabilidadSidePanelItem(
        icon: Icons.waterfall_chart_rounded,
        title: 'Flujo General',
        subtitle: 'Entradas y salidas reales consolidadas',
      ),
      const ContabilidadSidePanelItem(
        icon: Icons.receipt_long_rounded,
        title: 'Analisis de Gastos',
        subtitle: 'Clasificacion y trazabilidad por origen',
      ),
      const ContabilidadSidePanelItem(
        icon: Icons.assessment_rounded,
        title: 'Estado de Resultados',
        subtitle: 'Ingresos, costo, gasto y utilidad',
      ),
      const ContabilidadSidePanelItem(
        icon: Icons.rule_folder_rounded,
        title: 'Confiabilidad',
        subtitle: 'Cruces y validaciones de consistencia',
      ),
    ];

    return AreaThemeScope(
      tokens: contabilidadAreaTokens,
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
          background: const ContabilidadAreaBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => ContabilidadPageHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegacion',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) =>
              const ContabilidadPageHeaderBrand(title: 'Area de Contabilidad'),
          trailingBuilder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ContabilidadPageHeaderButton(
                label: 'Direccion',
                icon: Icons.north_west_rounded,
                onTap: _openDirectionDashboard,
              ),
              const SizedBox(width: 10),
              ContabilidadPageHeaderButton(
                label: 'Cerrar sesion',
                icon: Icons.logout_rounded,
                onTap: _logout,
              ),
            ],
          ),
          child: Stack(
            children: [
              const _ContabilidadDashboardBody(),
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
                        color: kContabilidadBg.withValues(alpha: 0.12),
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
                  child: ContabilidadAreaSidePanel(items: sidePanelItems),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContabilidadDashboardBody extends StatelessWidget {
  const _ContabilidadDashboardBody();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(56, 2, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ContabilidadHero(),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 1180;
                  if (isCompact) {
                    return const Column(
                      children: [
                        _ContabilidadReadOnlyCard(),
                        SizedBox(height: 14),
                        _ContabilidadSourceMapCard(),
                      ],
                    );
                  }
                  return const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _ContabilidadReadOnlyCard()),
                      SizedBox(width: 14),
                      Expanded(flex: 4, child: _ContabilidadSourceMapCard()),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'PANTALLAS CONTABLES',
                style: TextStyle(
                  color: kContabilidadMutedInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.1,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: const [
                  _ContabilidadModuleCard(
                    title: 'Flujo General',
                    badge: 'Flujo real',
                    icon: Icons.waterfall_chart_rounded,
                    summary:
                        'Consolida efectivo y bancos para entender cuanto dinero entro y salio realmente de la empresa en el periodo.',
                    sourceLines: [
                      'Boveda',
                      'Cuentas bancarias',
                      'Movimientos entre caja, deposito y retiro',
                    ],
                    outcome:
                        'Sirve para lectura de liquidez, no para utilidad por si solo.',
                  ),
                  _ContabilidadModuleCard(
                    title: 'Analisis de Gastos',
                    badge: 'Clasificacion',
                    icon: Icons.receipt_long_rounded,
                    summary:
                        'Ordena gastos por naturaleza, area, salida de efectivo y egreso bancario para separar gasto real de movimientos internos.',
                    sourceLines: [
                      'Boveda',
                      'Menudeo gastos-depositos',
                      'Pagos bancarios y reglas financieras',
                    ],
                    outcome:
                        'Permite distinguir gasto operativo, financiero y transferencias internas.',
                  ),
                  _ContabilidadModuleCard(
                    title: 'Estado de Resultados',
                    badge: 'Resultado',
                    icon: Icons.assessment_rounded,
                    summary:
                        'Cruza ingresos del periodo con costo y gastos para responder si el negocio gano o perdio en ese corte.',
                    sourceLines: [
                      'Ventas menudeo',
                      'Ventas mayoreo',
                      'Compras mayoreo',
                      'Analisis de gastos',
                    ],
                    outcome:
                        'Es la pantalla base para derivar utilidad bruta, operativa y neta.',
                  ),
                  _ContabilidadModuleCard(
                    title: 'Balance Compra-Venta',
                    badge: 'Comercial',
                    icon: Icons.swap_horiz_rounded,
                    summary:
                        'Mantiene el enfoque ejecutivo del diferencial entre lo comprado y lo vendido por periodo, sin forzarlo a ser utilidad.',
                    sourceLines: [
                      'Menudeo',
                      'Compras mayoreo',
                      'Ventas mayoreo',
                    ],
                    outcome:
                        'Sirve como lectura comercial y de tendencia, no como cierre contable final.',
                  ),
                  _ContabilidadModuleCard(
                    title: 'Confiabilidad',
                    badge: 'Control',
                    icon: Icons.rule_folder_rounded,
                    summary:
                        'Expone reglas de validacion para detectar inflacion, faltantes, reconstrucciones y diferencias aceptadas por criterio.',
                    sourceLines: [
                      'Cruces entre ventas, compras, efectivo y bancos',
                      'Revisiones por fecha de corte',
                      'Material general y faltantes aprobados',
                    ],
                    outcome:
                        'Ayuda a decidir si una utilidad es suficientemente confiable para decisiones contables.',
                  ),
                ],
              ),
              const SizedBox(height: 26),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContabilidadHero extends StatelessWidget {
  const _ContabilidadHero();

  @override
  Widget build(BuildContext context) {
    return ContabilidadPanel(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: kContabilidadGlow.withValues(alpha: 0.14),
              border: Border.all(
                color: kContabilidadGlow.withValues(alpha: 0.24),
              ),
            ),
            child: const Text(
              'Area nueva de lectura contable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Contabilidad no captura datos: consolida lo que ya vive en DICSA y lo traduce en lecturas contables confiables.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Aqui se separan con claridad flujo, gastos, resultado y utilidad para evitar usar un balance comercial como si fuera un estado contable final.',
            style: TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContabilidadReadOnlyCard extends StatelessWidget {
  const _ContabilidadReadOnlyCard();

  @override
  Widget build(BuildContext context) {
    return ContabilidadPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle(
            title: 'Principio del area',
            subtitle:
                'Todo se calcula leyendo otras areas; no existe captura contable manual aqui.',
          ),
          SizedBox(height: 18),
          _BulletLine(
            icon: Icons.lock_outline_rounded,
            text:
                'La fuente de verdad permanece en Menudeo, Mayoreo, Direccion y Finanzas.',
          ),
          SizedBox(height: 12),
          _BulletLine(
            icon: Icons.account_tree_outlined,
            text:
                'Contabilidad solo reacomoda, cruza y expone informacion para analisis y cierre.',
          ),
          SizedBox(height: 12),
          _BulletLine(
            icon: Icons.tune_rounded,
            text:
                'Cada pantalla contable debe tener criterio explicito de periodo, fuente y reglas de reconstruccion.',
          ),
        ],
      ),
    );
  }
}

class _ContabilidadSourceMapCard extends StatelessWidget {
  const _ContabilidadSourceMapCard();

  @override
  Widget build(BuildContext context) {
    return ContabilidadPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle(
            title: 'Mapa de fuentes',
            subtitle:
                'Primer acomodo propuesto para construir utilidad y estado de resultados.',
          ),
          SizedBox(height: 18),
          _SourceRow(
            title: 'Ingresos',
            detail: 'Ventas Menudeo y Ventas Mayoreo',
          ),
          SizedBox(height: 12),
          _SourceRow(
            title: 'Costo comercial',
            detail:
                'Balance Compra-Venta como lectura de costo y margen comercial',
          ),
          SizedBox(height: 12),
          _SourceRow(title: 'Flujo', detail: 'Boveda y Cuentas Bancarias'),
          SizedBox(height: 12),
          _SourceRow(
            title: 'Gastos',
            detail: 'Boveda, Menudeo gastos-depositos, pagos bancarios',
          ),
          SizedBox(height: 12),
          _SourceRow(
            title: 'Resultado final',
            detail: 'Estado de Resultados derivado de ingresos, costo y gasto',
          ),
        ],
      ),
    );
  }
}

class _ContabilidadModuleCard extends StatelessWidget {
  final String title;
  final String badge;
  final IconData icon;
  final String summary;
  final List<String> sourceLines;
  final String outcome;

  const _ContabilidadModuleCard({
    required this.title,
    required this.badge,
    required this.icon,
    required this.summary,
    required this.sourceLines,
    required this.outcome,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 480,
      child: ContabilidadPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: kContabilidadMint.withValues(alpha: 0.12),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              summary,
              style: const TextStyle(
                color: kContabilidadMutedInk,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Fuentes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            for (final line in sourceLines) ...[
              _BulletLine(
                icon: Icons.subdirectory_arrow_right_rounded,
                text: line,
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Text(
                outcome,
                style: const TextStyle(
                  color: kContabilidadInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: kContabilidadMutedInk,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _BulletLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BulletLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, color: kContabilidadGlow, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: kContabilidadInk,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  final String title;
  final String detail;

  const _SourceRow({required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              detail,
              style: const TextStyle(
                color: kContabilidadMutedInk,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
