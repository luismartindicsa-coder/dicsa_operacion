import 'package:flutter/material.dart';

import '../gerencia/gerencia_theme.dart';
import '../shared/archetypes/dashboard/empty_area_dashboard.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'management_reports_registry.dart';
import 'management_reports_widgets.dart';

class ManagementSupervisionPage extends StatelessWidget {
  final bool instantOpen;

  const ManagementSupervisionPage({super.key, this.instantOpen = false});

  static const EmptyAreaDashboardConfig _config = EmptyAreaDashboardConfig(
    dashboardLabel: 'Supervisión',
    sidePanelLabel: 'Supervisión',
    headerTitleColor: Colors.white,
    heroEyebrow: 'SUPERVISION POR AREAS',
    heroTitle: 'Reportes ejecutivos para coordinar, delegar y dar seguimiento.',
    heroSubtitle:
        'Hub central para generar cortes diarios y de viernes, revisar madurez de fuentes y empujar a cada encargado a llegar preparado a la junta.',
    emptyTitle: 'Supervisión profesional',
    emptySubtitle:
        'La app debe ayudar a que la gestión deje de depender de urgencias, memoria o persecución manual.',
    contractTitle: 'Contrato del módulo',
    contractSubtitle:
        'Supervisión no reemplaza operación. Lee, resume, evidencia desviaciones y deja responsables.',
    contractFootnote:
        'Los mismos botones de reporte deben vivir aquí y dentro del dashboard de cada área.',
    heroCardBorderColor: Color(0x40FF9FA7),
    heroCardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xF35B1623), Color(0xF325080F)],
    ),
    heroEyebrowColor: Color(0xFFFFC8CF),
    heroTitleColor: Color(0xFFFFFFFF),
    heroSubtitleColor: Color(0xCCFFE4E8),
    workspaceBodyColor: Color(0xCCFFE4E8),
    emptyStateSurfaceColor: Color(0xCC19070D),
    emptyStateBorderColor: Color(0x40FF9AA6),
    emptyStateIconColor: Color(0xFFFF9FA7),
    emptyStateBodyColor: Color(0xCCFFE4E8),
    contractPanelColor: Color(0xF3200A11),
    contractActionColor: Color(0x994A1520),
    contractActionHoverColor: Color(0xCC6A2130),
    contractActionIconColor: Color(0xFFFFC3CB),
    contractFootnoteColor: Color(0xCCFFE4E8),
    placeholderCardColor: Color(0xE0230B12),
    placeholderCardIconColor: Color(0xFFFFB4BC),
    placeholderCardDescriptionColor: Color(0xCCFFE4E8),
    placeholderCardArrowColor: Color(0xFFFFB4BC),
    tokens: gerenciaAreaTokens,
    ink: Color(0xFFFFFFFF),
    mutedInk: Color(0xCCFFE4E8),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF7A87), Color(0xFFD84B5B)],
    ),
    panelGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xE6250B12), Color(0xE61D0810)],
    ),
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFB23346), Color(0xFF4A1520)],
    ),
    backgroundGradientColors: [
      Color(0xFF12060A),
      Color(0xFF2E0C15),
      Color(0xFF5D1824),
    ],
    topLeftBlobColors: [Color(0xFF3A0F17), Color(0xFF16070B)],
    topRightBlobColors: [Color(0x66D65767), Color(0x11220B10)],
    bottomLeftBlobColors: [Color(0x33B93D50), Color(0x11FFD7DD)],
    pillarGradientColors: [Color(0x66FFB4BC), Color(0xFF1A0A10)],
    areaItems: <DashboardNavAction>[],
    showContractPanel: false,
    showPlaceholderCards: false,
  );

  @override
  Widget build(BuildContext context) {
    return EmptyAreaDashboardPage(
      instantOpen: instantOpen,
      config: _config.copyWith(
        areaItems: [
          DashboardNavAction(
            title: 'Supervisión por Áreas',
            subtitle: 'Hub central de generación y seguimiento',
            icon: Icons.fact_check_rounded,
            current: true,
            onTap: _noop,
          ),
        ],
        workspaceBuilder: (context, config, width) =>
            _ManagementSupervisionWorkspace(width: width),
      ),
    );
  }
}

Future<void> _noop() async {}

class _ManagementSupervisionWorkspace extends StatelessWidget {
  final double width;

  const _ManagementSupervisionWorkspace({required this.width});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final highPriority = managementAreaCatalog
        .where(
          (area) => <ManagementAreaKey>{
            ManagementAreaKey.finanzas,
            ManagementAreaKey.logistica,
            ManagementAreaKey.bascula,
            ManagementAreaKey.operaciones,
            ManagementAreaKey.gerencia,
            ManagementAreaKey.menudeo,
            ManagementAreaKey.contabilidad,
          }.contains(area.key),
        )
        .toList(growable: false);
    final pendingAreas = managementAreaCatalog
        .where((area) => !highPriority.contains(area))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ContractGlassCard(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lógica de adopción',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: tokens.onGlass,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Primero Gerencia genera y presenta junto con cada encargado. Después cada área debe generar, estudiar y defender su propio corte. El sistema existe para delegar con claridad, no para perseguir por memoria.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tokens.onGlass.withValues(alpha: 0.78),
                  height: 1.38,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _WorkspaceSection(
          title: 'Fase 1 · Áreas prioritarias',
          subtitle:
              'Fuentes más maduras para empezar a correr la junta del viernes con reportes reales desde la app.',
          children: highPriority
              .map(
                (area) => ManagementAreaReportPanel(
                  areaKey: area.key,
                  titleOverride: area.title,
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 18),
        _WorkspaceSection(
          title: 'Fases siguientes',
          subtitle:
              'Áreas que ya quedan visibles en el hub, aunque algunas fuentes sigan parciales o pendientes.',
          children: pendingAreas
              .map(
                (area) => ManagementAreaReportPanel(
                  areaKey: area.key,
                  titleOverride: area.title,
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _WorkspaceSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _WorkspaceSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w700,
                  color: Color(0xCCFFE4E8),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: children
              .map((child) => SizedBox(width: 420, child: child))
              .toList(growable: false),
        ),
      ],
    );
  }
}
