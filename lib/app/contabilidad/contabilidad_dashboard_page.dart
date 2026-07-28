import 'package:flutter/material.dart';

import 'contabilidad_area_chrome.dart';
import '../shared/archetypes/dashboard/empty_area_dashboard.dart';
import '../shared/page_routes.dart';
import 'contabilidad_flow_analysis_page.dart';
import 'contabilidad_income_statement_page.dart';
import 'contabilidad_trade_analysis_page.dart';
import 'contabilidad_theme.dart';

class ContabilidadDashboardPage extends StatelessWidget {
  final bool instantOpen;

  const ContabilidadDashboardPage({super.key, this.instantOpen = false});

  static const EmptyAreaDashboardConfig _config = EmptyAreaDashboardConfig(
    dashboardLabel: 'Contabilidad',
    sidePanelLabel: 'Contabilidad',
    headerTitleColor: Colors.white,
    heroEyebrow: 'AREA CONTABLE DICSA',
    heroTitle: 'Base homologada para flujo, gastos, utilidad y resultado.',
    heroSubtitle:
        'Contabilidad no captura datos nuevos. Lee lo ya registrado en otras areas de la app, lo cruza y lo expone con criterio contable.',
    emptyTitle: 'Lectura consolidada del negocio',
    emptySubtitle:
        'Esta area debe ordenar ingresos, costo, gastos y flujo para responder con claridad si el negocio gano o perdio en un periodo.',
    contractTitle: 'Contrato inicial del area',
    contractSubtitle:
        'Contabilidad vive como capa de lectura y calculo, nunca como origen manual alterno de informacion.',
    contractFootnote:
        'Fuentes base aprobadas: Menudeo, Ventas Mayoreo, Compras Mayoreo, Boveda y Cuentas Bancarias.',
    heroCardBorderColor: Color(0x4067D2D8),
    heroCardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xF3133B42), Color(0xF30B2025)],
    ),
    heroEyebrowColor: Color(0xFFB5F4F6),
    heroTitleColor: Color(0xFFFFFFFF),
    heroSubtitleColor: Color(0xCFF2FCFC),
    workspaceBodyColor: Color(0xCCF2FCFC),
    emptyStateSurfaceColor: Color(0xCC0D1F23),
    emptyStateBorderColor: Color(0x4067D2D8),
    emptyStateIconColor: Color(0xFF67D2D8),
    emptyStateBodyColor: Color(0xCCF2FCFC),
    contractPanelColor: Color(0xF3112A2F),
    contractActionColor: Color(0x99224248),
    contractActionHoverColor: Color(0xCC2C5B61),
    contractActionIconColor: Color(0xFFB5F4F6),
    contractFootnoteColor: Color(0xB8F2FCFC),
    placeholderCardColor: Color(0xE0143137),
    placeholderCardIconColor: Color(0xFF87E6BF),
    placeholderCardDescriptionColor: Color(0xB8F2FCFC),
    placeholderCardArrowColor: Color(0xFF67D2D8),
    tokens: contabilidadAreaTokens,
    ink: Color(0xFFFFFFFF),
    mutedInk: Color(0xCCF2FCFC),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF67D2D8), Color(0xFF87E6BF)],
    ),
    panelGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xE6122D33), Color(0xE60D2025)],
    ),
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A5259), Color(0xFF10353A)],
    ),
    backgroundGradientColors: [
      Color(0xFF07161A),
      Color(0xFF0B2328),
      Color(0xFF10343A),
    ],
    topLeftBlobColors: [Color(0xFF12343A), Color(0xFF061215)],
    topRightBlobColors: [Color(0x6667D2D8), Color(0x11143539)],
    bottomLeftBlobColors: [Color(0x3387E6BF), Color(0x11E8FFFF)],
    pillarGradientColors: [Color(0x6687E6BF), Color(0xFF0B1D21)],
    areaItems: <DashboardNavAction>[],
    showContractPanel: false,
    showPlaceholderCards: false,
    sidePanelBuilder: _buildContabilidadSidePanel,
  );

  @override
  Widget build(BuildContext context) {
    Future<void> openTradeBalance() async {
      await Navigator.of(context).push(
        appPageRoute(
          page: const ContabilidadTradeAnalysisPage(instantOpen: true),
        ),
      );
    }

    Future<void> openFlow() async {
      await Navigator.of(context).push(
        appPageRoute(
          page: const ContabilidadFlowAnalysisPage(instantOpen: true),
        ),
      );
    }

    Future<void> openIncomeStatement() async {
      await Navigator.of(context).push(
        appPageRoute(
          page: const ContabilidadIncomeStatementPage(instantOpen: true),
        ),
      );
    }

    return EmptyAreaDashboardPage(
      instantOpen: instantOpen,
      config: _config.copyWith(
        areaItems: buildContabilidadAreaItems(
          current: ContabilidadAreaScreen.dashboard,
          onOpenTradeBalance: openTradeBalance,
          onOpenFlujoGeneral: openFlow,
          onOpenEstadoResultados: openIncomeStatement,
        ),
        accessItems: buildContabilidadAccessItems(
          current: ContabilidadAreaScreen.dashboard,
          onOpenDashboard: _noop,
        ),
        workspaceBuilder: (context, config, width) =>
            _ContabilidadDashboardWorkspace(width: width),
      ),
    );
  }
}

Widget _buildContabilidadSidePanel(
  BuildContext context,
  EmptyAreaDashboardConfig config,
  bool canReturnToDirection,
  List<DashboardNavAction> accessItems,
  List<DashboardNavAction> areaItems,
) {
  return ContabilidadAreaSidePanel(
    label: config.sidePanelLabel,
    canReturnToDirection: canReturnToDirection,
    areaItems: areaItems,
    accessItems: accessItems,
  );
}

class _ContabilidadDashboardWorkspace extends StatelessWidget {
  final double width;

  const _ContabilidadDashboardWorkspace({required this.width});

  @override
  Widget build(BuildContext context) {
    final isCompact = width < 1180;
    final modules = const [
      _ContabilidadModuleSpec(
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
      _ContabilidadModuleSpec(
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
      _ContabilidadModuleSpec(
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
      _ContabilidadModuleSpec(
        title: 'Resultado Comercial',
        badge: 'Comercial',
        icon: Icons.swap_horiz_rounded,
        summary:
            'Ordena compra, venta y margen comercial del periodo sin confundirlo con utilidad neta.',
        sourceLines: ['Menudeo', 'Compras mayoreo', 'Ventas mayoreo'],
        outcome:
            'Sirve como lectura comercial base para costo y margen, no como cierre contable final.',
      ),
      _ContabilidadModuleSpec(
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
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ContabilidadHeroPanel(width: width),
        const SizedBox(height: 16),
        if (isCompact) ...[
          const _ContabilidadReadOnlyCard(),
          const SizedBox(height: 12),
          const _ContabilidadSourceMapCard(),
        ] else
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _ContabilidadReadOnlyCard()),
              SizedBox(width: 12),
              Expanded(flex: 4, child: _ContabilidadSourceMapCard()),
            ],
          ),
        const SizedBox(height: 18),
        const Text(
          'PANTALLAS CONTABLES',
          style: TextStyle(
            color: Color(0xB8F2FCFC),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: modules
              .map(
                (module) => SizedBox(
                  width: width >= 1450 ? 470 : 420,
                  child: _ContabilidadModuleCard(spec: module),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _ContabilidadHeroPanel extends StatelessWidget {
  final double width;

  const _ContabilidadHeroPanel({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE6133B42), Color(0xE60B2025)],
        ),
        border: Border.all(color: const Color(0x4067D2D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: const Color(0xFF67D2D8).withValues(alpha: 0.16),
              border: Border.all(
                color: const Color(0xFF67D2D8).withValues(alpha: 0.26),
              ),
            ),
            child: const Text(
              'Lectura contable homologada',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            width < 980
                ? 'Contabilidad consolida y ordena la informacion ya capturada en DICSA.'
                : 'Contabilidad no captura datos nuevos: consolida, cruza y ordena la informacion ya capturada en DICSA.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Aqui se separan con claridad flujo, gastos, balance comercial y estado de resultados para no confundir una lectura ejecutiva con una utilidad contable final.',
            style: TextStyle(
              color: Color(0xCCF2FCFC),
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
    return _ContabilidadSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _ContabilidadSectionTitle(
            title: 'Principio del area',
            subtitle:
                'Todo se calcula leyendo otras areas; no existe captura contable manual aqui.',
          ),
          SizedBox(height: 18),
          _ContabilidadBulletLine(
            icon: Icons.lock_outline_rounded,
            text:
                'La fuente de verdad permanece en Menudeo, Mayoreo, Direccion y Finanzas.',
          ),
          SizedBox(height: 12),
          _ContabilidadBulletLine(
            icon: Icons.account_tree_outlined,
            text:
                'Contabilidad solo reacomoda, cruza y expone informacion para analisis y cierre.',
          ),
          SizedBox(height: 12),
          _ContabilidadBulletLine(
            icon: Icons.tune_rounded,
            text:
                'Cada pantalla contable debe declarar periodo, fuente y reglas de reconstruccion o exclusion.',
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
    return _ContabilidadSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _ContabilidadSectionTitle(
            title: 'Mapa de fuentes',
            subtitle:
                'Primer acomodo propuesto para construir utilidad y estado de resultados.',
          ),
          SizedBox(height: 18),
          _ContabilidadSourceRow(
            title: 'Ingresos',
            detail: 'Ventas Menudeo y Ventas Mayoreo',
          ),
          SizedBox(height: 12),
          _ContabilidadSourceRow(
            title: 'Costo comercial',
            detail:
                'Resultado Comercial como lectura de costo y margen comercial',
          ),
          SizedBox(height: 12),
          _ContabilidadSourceRow(
            title: 'Flujo',
            detail: 'Boveda y Cuentas Bancarias',
          ),
          SizedBox(height: 12),
          _ContabilidadSourceRow(
            title: 'Gastos',
            detail: 'Boveda, Menudeo gastos-depositos y pagos bancarios',
          ),
          SizedBox(height: 12),
          _ContabilidadSourceRow(
            title: 'Resultado final',
            detail: 'Estado de Resultados derivado de ingresos, costo y gasto',
          ),
        ],
      ),
    );
  }
}

class _ContabilidadModuleCard extends StatelessWidget {
  final _ContabilidadModuleSpec spec;

  const _ContabilidadModuleCard({required this.spec});

  @override
  Widget build(BuildContext context) {
    return _ContabilidadSurfaceCard(
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
                child: Icon(spec.icon, color: Colors.white, size: 22),
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
                        color: const Color(0xFF87E6BF).withValues(alpha: 0.12),
                      ),
                      child: Text(
                        spec.badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      spec.title,
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
            spec.summary,
            style: const TextStyle(
              color: Color(0xCCF2FCFC),
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
          for (final line in spec.sourceLines) ...[
            _ContabilidadBulletLine(
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
              spec.outcome,
              style: const TextStyle(
                color: Color(0xFFF2FCFC),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContabilidadSurfaceCard extends StatelessWidget {
  final Widget child;

  const _ContabilidadSurfaceCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE6122D33), Color(0xE60D2025)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: child,
    );
  }
}

class _ContabilidadSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ContabilidadSectionTitle({
    required this.title,
    required this.subtitle,
  });

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
            color: Color(0xCCF2FCFC),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _ContabilidadBulletLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContabilidadBulletLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, color: const Color(0xFF67D2D8), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFF2FCFC),
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

class _ContabilidadSourceRow extends StatelessWidget {
  final String title;
  final String detail;

  const _ContabilidadSourceRow({required this.title, required this.detail});

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
                color: Color(0xCCF2FCFC),
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

class _ContabilidadModuleSpec {
  final String title;
  final String badge;
  final IconData icon;
  final String summary;
  final List<String> sourceLines;
  final String outcome;

  const _ContabilidadModuleSpec({
    required this.title,
    required this.badge,
    required this.icon,
    required this.summary,
    required this.sourceLines,
    required this.outcome,
  });
}

Future<void> _noop() async {}
