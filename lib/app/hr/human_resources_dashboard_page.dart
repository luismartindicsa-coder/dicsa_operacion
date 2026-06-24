import 'package:flutter/material.dart';

import '../shared/archetypes/dashboard/empty_area_dashboard.dart';
import '../shared/page_routes.dart';
import 'human_resources_personnel_page.dart';
import 'human_resources_mock_page.dart';
import 'human_resources_theme.dart';

class HumanResourcesDashboardPage extends StatelessWidget {
  final bool instantOpen;

  const HumanResourcesDashboardPage({super.key, this.instantOpen = false});

  static const EmptyAreaDashboardConfig _config = EmptyAreaDashboardConfig(
    dashboardLabel: 'Recursos Humanos',
    sidePanelLabel: 'Recursos Humanos',
    headerTitleColor: Colors.white,
    heroEyebrow: 'AREA NUEVA DICSA',
    heroTitle: 'Base homologada para nomina, personal e incidencias.',
    heroSubtitle:
        'RH arranca sobre el dashboard compartido de la app para conservar shell, navegacion, overlays y contrato visual mientras definimos sus pantallas operativas y de calculo.',
    emptyTitle: 'Fase 1 en activacion',
    emptySubtitle:
        'Esta superficie ya vive como area formal dentro de la app. A partir de aqui se deben derivar modulos con formulas reproducibles, trazabilidad de importaciones y cruces controlados con Finanzas.',
    contractTitle: 'Contrato inicial del area',
    contractSubtitle:
        'Las pantallas de RH deben reutilizar arquetipos homologados, heredar tokens del area y evitar formulas opacas o calculos dispersos por widget.',
    contractFootnote:
        'Cruce principal aprobado: pagos de nomina, impuestos e IMSS contra cuentas bancarias de Finanzas; el calculo fuente y las incidencias nacen en RH.',
    heroCardBorderColor: Color(0x40B17EFF),
    heroCardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xF34C267A), Color(0xF32A1844)],
    ),
    heroEyebrowColor: Color(0xFFCFAEFF),
    heroTitleColor: Color(0xFFFFFFFF),
    heroSubtitleColor: Color(0xBFFFFFFF),
    workspaceBodyColor: Color(0xC7FFFFFF),
    emptyStateSurfaceColor: Color(0xCC1D112F),
    emptyStateBorderColor: Color(0x40B68CFF),
    emptyStateIconColor: Color(0xFFB68CFF),
    emptyStateBodyColor: Color(0xA6FFFFFF),
    contractPanelColor: Color(0xF3201233),
    contractActionColor: Color(0x99432A65),
    contractActionHoverColor: Color(0xCC6B46C1),
    contractActionIconColor: Color(0xFFC79CFF),
    contractFootnoteColor: Color(0x8CFFFFFF),
    placeholderCardColor: Color(0xE025163A),
    placeholderCardIconColor: Color(0xFFB68CFF),
    placeholderCardDescriptionColor: Color(0x8CFFFFFF),
    placeholderCardArrowColor: Color(0xFFB68CFF),
    tokens: humanResourcesAreaTokens,
    ink: Color(0xFFFFFFFF),
    mutedInk: Color(0x8CFFFFFF),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF9F6BFF), Color(0xFFB68CFF)],
    ),
    panelGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xE625163A), Color(0xE625163A)],
    ),
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF6E47A8), Color(0xFF24103D)],
    ),
    backgroundGradientColors: [
      Color(0xFF140B25),
      Color(0xFF24103F),
      Color(0xFF4A1D7A),
    ],
    topLeftBlobColors: [Color(0xFF2A174A), Color(0xFF12091F)],
    topRightBlobColors: [Color(0xFF9465F4), Color(0x33261540)],
    bottomLeftBlobColors: [Color(0x33573797), Color(0xFFE9D8FF)],
    pillarGradientColors: [Color(0xFFC6AAFF), Color(0xFF1A0E31)],
    areaItems: <DashboardNavAction>[],
    placeholderCards: <DashboardPlaceholderCard>[
      DashboardPlaceholderCard(
        icon: Icons.badge_outlined,
        title: 'Personal',
        description:
            'Expediente, estatus, empresa y esquema de pago listos para aterrizar como superficie real.',
      ),
      DashboardPlaceholderCard(
        icon: Icons.schedule_rounded,
        title: 'Asistencia e incidencias',
        description:
            'Importaciones de reloj checador, permisos, vacaciones y horas extra con staging validable.',
      ),
      DashboardPlaceholderCard(
        icon: Icons.payments_outlined,
        title: 'Prenomina y obligaciones',
        description:
            'Corridas reproducibles para nomina, impuestos e IMSS con puente controlado hacia Finanzas.',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    Future<void> openPersonnel() async {
      await Navigator.of(context).push(
        appPageRoute(
          page: const HumanResourcesPersonnelPage(instantOpen: true),
        ),
      );
    }

    Future<void> openMockVisual() async {
      await Navigator.of(
        context,
      ).push(appPageRoute(page: const HumanResourcesMockPage()));
    }

    return EmptyAreaDashboardPage(
      instantOpen: instantOpen,
      config: _config.copyWith(
        areaItems: [
          const DashboardNavAction(
            title: 'Dashboard RH',
            subtitle: 'Activacion inicial homologada',
            icon: Icons.space_dashboard_rounded,
            current: true,
            onTap: _noop,
          ),
          DashboardNavAction(
            title: 'Personal',
            subtitle: 'Expediente operativo y adscripción',
            icon: Icons.badge_outlined,
            onTap: openPersonnel,
          ),
          DashboardNavAction(
            title: 'Mock visual RH',
            subtitle: 'Referencia cromatica y atmosferica actual',
            icon: Icons.auto_awesome_rounded,
            onTap: openMockVisual,
          ),
        ],
      ),
    );
  }
}

Future<void> _noop() async {}
