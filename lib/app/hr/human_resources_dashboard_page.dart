import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared/archetypes/dashboard/empty_area_dashboard.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'human_resources_attendance_page.dart';
import 'human_resources_attendance_incidents_page.dart';
import 'human_resources_permissions_page.dart';
import 'human_resources_personnel_page.dart';
import 'human_resources_prenomina_page.dart';
import 'human_resources_theme.dart';
import 'human_resources_vacations_page.dart';

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
        title: 'Importación y conciliación',
        description:
            'Lectura y cruce de NGTeco y CONTPAQ para conciliación operativa.',
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

    Future<void> openAttendance() async {
      await Navigator.of(context).push(
        appPageRoute(
          page: const HumanResourcesAttendancePage(instantOpen: true),
        ),
      );
    }

    Future<void> openImportConciliation() async {
      await Navigator.of(context).push(
        appPageRoute(
          page: const HumanResourcesAttendanceIncidentsPage(instantOpen: true),
        ),
      );
    }

    Future<void> openVacations() async {
      await Navigator.of(context).push(
        appPageRoute(
          page: const HumanResourcesVacationsPage(instantOpen: true),
        ),
      );
    }

    Future<void> openPermissions() async {
      await Navigator.of(context).push(
        appPageRoute(
          page: const HumanResourcesPermissionsPage(instantOpen: true),
        ),
      );
    }

    Future<void> openPrenomina() async {
      await Navigator.of(context).push(
        appPageRoute(
          page: const HumanResourcesPrenominaPage(instantOpen: true),
        ),
      );
    }

    return EmptyAreaDashboardPage(
      instantOpen: instantOpen,
      config: _config.copyWith(
        workspaceBuilder: (context, config, width) => _HrDashboardWorkspace(
          width: width,
          onOpenPersonnel: openPersonnel,
          onOpenAttendance: openAttendance,
          onOpenImportConciliation: openImportConciliation,
          onOpenVacations: openVacations,
          onOpenPermissions: openPermissions,
          onOpenPrenomina: openPrenomina,
        ),
        showHeroPanel: false,
        showContractPanel: false,
        showPlaceholderCards: false,
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
            title: 'Asistencia',
            subtitle: 'Cierre editable semanal por colaborador',
            icon: Icons.fact_check_outlined,
            onTap: openAttendance,
          ),
          DashboardNavAction(
            title: 'Importación y conciliación',
            subtitle: 'Lectura y cruce de NGTeco y CONTPAQ',
            icon: Icons.schedule_rounded,
            onTap: openImportConciliation,
          ),
          DashboardNavAction(
            title: 'Vacaciones',
            subtitle: 'Derecho, saldo y aplicación por ejercicio',
            icon: Icons.beach_access_rounded,
            onTap: openVacations,
          ),
          DashboardNavAction(
            title: 'Permisos',
            subtitle: 'Ledger operativo por periodo y colaborador',
            icon: Icons.assignment_turned_in_outlined,
            onTap: openPermissions,
          ),
          DashboardNavAction(
            title: 'Prenómina',
            subtitle: 'Corrida borrador semanal por colaborador',
            icon: Icons.payments_outlined,
            onTap: openPrenomina,
          ),
        ],
      ),
    );
  }
}

Future<void> _noop() async {}

class _HrDashboardWorkspace extends StatelessWidget {
  final double width;
  final Future<void> Function() onOpenPersonnel;
  final Future<void> Function() onOpenAttendance;
  final Future<void> Function() onOpenImportConciliation;
  final Future<void> Function() onOpenVacations;
  final Future<void> Function() onOpenPermissions;
  final Future<void> Function() onOpenPrenomina;

  const _HrDashboardWorkspace({
    required this.width,
    required this.onOpenPersonnel,
    required this.onOpenAttendance,
    required this.onOpenImportConciliation,
    required this.onOpenVacations,
    required this.onOpenPermissions,
    required this.onOpenPrenomina,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _HrDashboardPersonnelSummaryCard(onTap: onOpenPersonnel),
            _HrDashboardSimpleShortcutCard(
              icon: Icons.fact_check_outlined,
              title: 'Asistencia',
              subtitle: 'Cierre editable semanal por colaborador',
              onTap: onOpenAttendance,
            ),
            _HrDashboardSimpleShortcutCard(
              icon: Icons.schedule_rounded,
              title: 'Importación y conciliación',
              subtitle: 'Lectura y cruce de NGTeco y CONTPAQ',
              onTap: onOpenImportConciliation,
            ),
            _HrDashboardSimpleShortcutCard(
              icon: Icons.beach_access_rounded,
              title: 'Vacaciones',
              subtitle: 'Derecho, aplicación y saldo por ejercicio',
              onTap: onOpenVacations,
            ),
            _HrDashboardSimpleShortcutCard(
              icon: Icons.assignment_turned_in_outlined,
              title: 'Permisos',
              subtitle: 'Captura administrativa por colaborador y periodo',
              onTap: onOpenPermissions,
            ),
            _HrDashboardSimpleShortcutCard(
              icon: Icons.payments_outlined,
              title: 'Prenómina',
              subtitle: 'Corrida borrador semanal por colaborador',
              onTap: onOpenPrenomina,
            ),
          ],
        ),
      ),
    );
  }
}

class _HrDashboardPersonnelSummaryCard extends StatefulWidget {
  final Future<void> Function() onTap;

  const _HrDashboardPersonnelSummaryCard({required this.onTap});

  @override
  State<_HrDashboardPersonnelSummaryCard> createState() =>
      _HrDashboardPersonnelSummaryCardState();
}

class _HrDashboardSimpleShortcutCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onTap;

  const _HrDashboardSimpleShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_HrDashboardSimpleShortcutCard> createState() =>
      _HrDashboardSimpleShortcutCardState();
}

class _HrDashboardSimpleShortcutCardState
    extends State<_HrDashboardSimpleShortcutCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: _hovered ? 1.015 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async => widget.onTap(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
              width: 320,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xE625163A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _hovered
                      ? const Color(0x66C79CFF)
                      : const Color(0x33B084FF),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _hovered ? 0.24 : 0.14,
                    ),
                    blurRadius: _hovered ? 26 : 18,
                    offset: Offset(0, _hovered ? 14 : 10),
                  ),
                  BoxShadow(
                    color: tokens.glow.withValues(
                      alpha: _hovered ? 0.12 : 0.06,
                    ),
                    blurRadius: _hovered ? 18 : 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF9F6BFF), Color(0xFF6E47A8)],
                      ),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Icon(widget.icon, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            color: Colors.white.withValues(alpha: 0.66),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: const Color(
                      0xFFCFAEFF,
                    ).withValues(alpha: _hovered ? 1 : 0.84),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HrDashboardPersonnelSummaryCardState
    extends State<_HrDashboardPersonnelSummaryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: _hovered ? 1.015 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async => widget.onTap(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
              width: 320,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xE625163A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _hovered
                      ? const Color(0x66C79CFF)
                      : const Color(0x33B084FF),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _hovered ? 0.24 : 0.14,
                    ),
                    blurRadius: _hovered ? 26 : 18,
                    offset: Offset(0, _hovered ? 14 : 10),
                  ),
                  BoxShadow(
                    color: tokens.glow.withValues(
                      alpha: _hovered ? 0.12 : 0.06,
                    ),
                    blurRadius: _hovered ? 18 : 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF9F6BFF), Color(0xFF6E47A8)],
                      ),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: const Icon(
                      Icons.badge_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Personal',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Colors.white.withValues(alpha: 0.60),
                          ),
                        ),
                        const SizedBox(height: 3),
                        FutureBuilder<List<dynamic>>(
                          future: Supabase.instance.client
                              .from('hr_employee_profiles')
                              .select('id'),
                          builder: (context, snapshot) {
                            final total = snapshot.data?.length ?? 0;
                            final loading =
                                snapshot.connectionState !=
                                ConnectionState.done;
                            return Text(
                              loading ? '...' : '$total empleados',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white.withValues(alpha: 0.96),
                                height: 1,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Abrir expediente digital',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFCFAEFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _hovered
                          ? const Color(0xFF9F6BFF)
                          : const Color(0x33432A65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hovered
                            ? const Color(0x80FFFFFF)
                            : const Color(0x33C79CFF),
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: _hovered ? Colors.white : const Color(0xFFC79CFF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
