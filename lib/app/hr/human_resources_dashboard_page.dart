import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dashboard/general_dashboard_page.dart';
import '../shared/archetypes/dashboard/empty_area_dashboard.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'human_resources_attendance_page.dart';
import 'human_resources_attendance_incidents_page.dart';
import 'human_resources_area_chrome.dart';
import 'human_resources_nomina_page.dart';
import 'human_resources_permissions_page.dart';
import 'human_resources_personnel_page.dart';
import 'human_resources_period_context.dart';
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

    Future<void> openNomina() async {
      await Navigator.of(context).push(
        appPageRoute(page: const HumanResourcesNominaPage(instantOpen: true)),
      );
    }

    Future<void> openDirectionDashboard() async {
      await Navigator.of(context).pushReplacement(
        appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
      );
    }

    return EmptyAreaDashboardPage(
      instantOpen: instantOpen,
      config: _config.copyWith(
        workspaceBuilder: (context, config, width) => _HrOperationsDashboard(
          width: width,
          onOpenPersonnel: openPersonnel,
          onOpenAttendance: openAttendance,
          onOpenImportConciliation: openImportConciliation,
          onOpenVacations: openVacations,
          onOpenPermissions: openPermissions,
          onOpenPrenomina: openPrenomina,
          onOpenNomina: openNomina,
        ),
        sidePanelBuilder:
            (context, config, canReturnToDirection, accessItems, areaItems) =>
                HumanResourcesAreaSidePanel(
                  label: 'Recursos Humanos',
                  canReturnToDirection: canReturnToDirection,
                  sections: buildHumanResourcesAreaSections(
                    activeScreen: HumanResourcesAreaScreen.dashboard,
                    openPersonnel: openPersonnel,
                    openAttendance: openAttendance,
                    openImportConciliation: openImportConciliation,
                    openVacations: openVacations,
                    openPermissions: openPermissions,
                    openPrenomina: openPrenomina,
                    openNomina: openNomina,
                  ),
                  accessItems: buildHumanResourcesAccessItems(
                    activeScreen: HumanResourcesAreaScreen.dashboard,
                    openDashboard: _noop,
                    canReturnToDirection: canReturnToDirection,
                    openDirectionDashboard: openDirectionDashboard,
                  ),
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
            title: 'Importación y conciliación',
            subtitle: 'Lectura y cruce de NGTeco y CONTPAQ',
            icon: Icons.schedule_rounded,
            onTap: openImportConciliation,
          ),
          DashboardNavAction(
            title: 'Asistencia',
            subtitle: 'Cierre editable semanal por colaborador',
            icon: Icons.fact_check_outlined,
            onTap: openAttendance,
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
          DashboardNavAction(
            title: 'Nómina',
            subtitle: 'Cierre comparativo final del periodo',
            icon: Icons.receipt_long_rounded,
            onTap: openNomina,
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
  final Future<void> Function() onOpenNomina;

  const _HrDashboardWorkspace({
    required this.width,
    required this.onOpenPersonnel,
    required this.onOpenAttendance,
    required this.onOpenImportConciliation,
    required this.onOpenVacations,
    required this.onOpenPermissions,
    required this.onOpenPrenomina,
    required this.onOpenNomina,
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
            _HrDashboardSimpleShortcutCard(
              icon: Icons.receipt_long_rounded,
              title: 'Nómina',
              subtitle: 'Cierre comparativo final y validación',
              onTap: onOpenNomina,
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
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: fetchAllSupabaseRows(
                            (from, to) => Supabase.instance.client
                                .from('hr_employee_profiles')
                                .select('id')
                                .order('id')
                                .range(from, to),
                          ),
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

class _HrOperationsDashboard extends StatefulWidget {
  final double width;
  final Future<void> Function() onOpenPersonnel;
  final Future<void> Function() onOpenAttendance;
  final Future<void> Function() onOpenImportConciliation;
  final Future<void> Function() onOpenVacations;
  final Future<void> Function() onOpenPermissions;
  final Future<void> Function() onOpenPrenomina;
  final Future<void> Function() onOpenNomina;

  const _HrOperationsDashboard({
    required this.width,
    required this.onOpenPersonnel,
    required this.onOpenAttendance,
    required this.onOpenImportConciliation,
    required this.onOpenVacations,
    required this.onOpenPermissions,
    required this.onOpenPrenomina,
    required this.onOpenNomina,
  });

  @override
  State<_HrOperationsDashboard> createState() => _HrOperationsDashboardState();
}

class _HrOperationsDashboardState extends State<_HrOperationsDashboard> {
  bool _loading = true;
  String? _error;
  _HrDashboardData _data = const _HrDashboardData.empty();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final selectedPeriodLabel =
          await HumanResourcesPeriodContext.readSelectedLabel();
      final client = Supabase.instance.client;
      final results = await Future.wait<List<Map<String, dynamic>>>([
        fetchAllSupabaseRows(
          (from, to) => client
              .from('hr_employee_profiles')
              .select('id,nombre,empresa')
              .order('id')
              .range(from, to),
        ),
        fetchAllSupabaseRows(
          (from, to) => client
              .from('hr_attendance_import_lots')
              .select('source,period_label,imported_at')
              .order('imported_at', ascending: false)
              .range(from, to),
        ),
        fetchAllSupabaseRows(
          (from, to) => client
              .from('hr_attendance_daily_records')
              .select(
                'period_label,employee_id,employee_name,status,late_minutes,overtime_minutes',
              )
              .order('source_date')
              .range(from, to),
        ),
        fetchAllSupabaseRows(
          (from, to) => client
              .from('hr_employee_vacation_events')
              .select(
                'employee_id,employee_name,attendance_period_label,event_type,status,start_date,end_date,days_applied',
              )
              .order('start_date')
              .range(from, to),
        ),
        fetchAllSupabaseRows(
          (from, to) => client
              .from('hr_employee_permission_events')
              .select(
                'employee_id,employee_name,empresa,attendance_period_label,permission_type,status,start_date,end_date,quantity_days,quantity_hours',
              )
              .order('start_date')
              .range(from, to),
        ),
        fetchAllSupabaseRows(
          (from, to) => client
              .from('hr_prenomina_draft_rows')
              .select(
                'period_label,employee_id,employee_name,empresa,draft_status,'
                'manual_adjustment_amount,fiscal_net_amount,fiscal_late_deduction_amount,fiscal_vacation_amount,'
                'cash_salary_amount,cash_vacation_amount,cash_isr_amount,transport_support_amount,holiday_amount,'
                'overtime_monetized_amount,manual_bonus_amount,cash_absence_deduction_amount,'
                'cash_infonavit_deduction_amount,cash_fonacot_deduction_amount,loan_deduction_amount,'
                'payment_outside_amount',
              )
              .order('period_label')
              .range(from, to),
        ),
        fetchAllSupabaseRows(
          (from, to) => client
              .from('hr_payroll_period_closures')
              .select('period_label,status')
              .order('created_at', ascending: false)
              .range(from, to),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _data = _HrDashboardData.fromRows(
          selectedPeriodLabel: selectedPeriodLabel,
          profiles: results[0],
          importLots: results[1],
          attendanceRecords: results[2],
          vacationEvents: results[3],
          permissionEvents: results[4],
          prenominaDrafts: results[5],
          periodClosures: results[6],
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo actualizar el resumen de Recursos Humanos.';
      });
    }
  }

  Future<void> _selectPeriod(String label) async {
    await HumanResourcesPeriodContext.select(label);
    if (!mounted) return;
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return SizedBox(
      width: widget.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dashboardTopBar(data),
          const SizedBox(height: 12),
          _workflow(data),
          const SizedBox(height: 22),
          _sectionHeader(
            title: 'Resumen general',
            detail: data.periodDescription,
          ),
          const SizedBox(height: 10),
          if (_error != null) _dashboardErrorCard(),
          _summaryMetrics(data),
          const SizedBox(height: 14),
          _operationalInsights(data),
          const SizedBox(height: 14),
          _payrollAndVacationInsights(data),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                minHeight: 3,
                color: Color(0xFF9F6BFF),
                backgroundColor: Color(0x334C267A),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dashboardTopBar(_HrDashboardData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final selector = HumanResourcesPeriodSelector(
          selectedLabel: data.activePeriodLabel,
          options: data.periodOptions,
          onSelected: _selectPeriod,
        );
        final refresh = _HrDashboardRoundAction(
          tooltip: 'Actualizar resumen',
          icon: Icons.refresh_rounded,
          onTap: _loading ? null : _loadData,
        );
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Flujo de trabajo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: selector),
                  const SizedBox(width: 8),
                  refresh,
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            const Expanded(
              child: Text(
                'Flujo de trabajo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            Flexible(child: selector),
            const SizedBox(width: 8),
            refresh,
          ],
        );
      },
    );
  }

  Widget _workflow(_HrDashboardData data) {
    final steps = [
      _HrDashboardFlowStep(
        icon: Icons.badge_outlined,
        title: 'Personal',
        detail: '${data.employeeCount} colaboradores',
        onTap: widget.onOpenPersonnel,
      ),
      _HrDashboardFlowStep(
        icon: Icons.cloud_upload_outlined,
        title: 'Importación y conciliación',
        detail: data.importStatus,
        onTap: widget.onOpenImportConciliation,
      ),
      _HrDashboardFlowStep(
        icon: Icons.fact_check_outlined,
        title: 'Asistencia',
        detail: data.attendanceFlowDetail,
        onTap: widget.onOpenAttendance,
      ),
      _HrDashboardFlowStep(
        icon: Icons.assignment_turned_in_outlined,
        title: 'Permisos',
        detail: data.permissionFlowDetail,
        onTap: widget.onOpenPermissions,
      ),
      _HrDashboardFlowStep(
        icon: Icons.payments_outlined,
        title: 'Prenómina',
        detail: data.prenominaFlowDetail,
        onTap: widget.onOpenPrenomina,
      ),
      _HrDashboardFlowStep(
        icon: Icons.receipt_long_rounded,
        title: 'Nómina',
        detail: data.nominaFlowDetail,
        onTap: widget.onOpenNomina,
      ),
      _HrDashboardFlowStep(
        icon: Icons.beach_access_rounded,
        title: 'Vacaciones',
        detail: '${data.activeVacationEmployees} activas ahora',
        onTap: widget.onOpenVacations,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1280) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < steps.length; index++) ...[
                Expanded(
                  child: _HrDashboardFlowCard(
                    index: index + 1,
                    step: steps[index],
                  ),
                ),
                if (index != steps.length - 1)
                  const SizedBox(
                    width: 24,
                    height: 86,
                    child: Center(
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 22,
                        color: Color(0xFFB68CFF),
                      ),
                    ),
                  ),
              ],
            ],
          );
        }
        final columns = constraints.maxWidth >= 760 ? 2 : 1;
        final cardWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var index = 0; index < steps.length; index++)
              SizedBox(
                width: cardWidth,
                child: _HrDashboardFlowCard(
                  index: index + 1,
                  step: steps[index],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _summaryMetrics(_HrDashboardData data) {
    return _HrDashboardResponsiveGrid(
      minWideColumns: 6,
      children: [
        _HrDashboardMetricCard(
          icon: Icons.groups_2_outlined,
          iconColor: const Color(0xFFD491FF),
          title: 'Total empleados',
          value: '${data.employeeCount}',
          detail: 'Expedientes en Personal',
          chart: _HrDashboardMiniBars(
            values: data.companyCounts.values.toList(),
          ),
          onTap: widget.onOpenPersonnel,
        ),
        _HrDashboardAttendanceCard(data: data, onTap: widget.onOpenAttendance),
        _HrDashboardMetricCard(
          icon: Icons.assignment_turned_in_outlined,
          iconColor: const Color(0xFFBFA2FF),
          title: 'Permisos del periodo',
          value: data.periodValue(data.permissionEventsCount),
          detail: data.hasPeriod
              ? '${data.permissionPendingCount} pendiente(s) de aplicar'
              : 'Elige un periodo operativo',
          chart: _HrDashboardMiniBars(
            values: data.permissionDistribution.values.toList(),
          ),
          onTap: widget.onOpenPermissions,
        ),
        _HrDashboardMetricCard(
          icon: Icons.beach_access_rounded,
          iconColor: const Color(0xFF57D9AD),
          title: 'Vacaciones activas',
          value: '${data.activeVacationEmployees}',
          detail: 'Colaboradores en vacaciones hoy',
          chart: _HrDashboardMiniBars(values: data.activeVacationTrend),
          onTap: widget.onOpenVacations,
        ),
        _HrDashboardMetricCard(
          icon: Icons.event_available_outlined,
          iconColor: const Color(0xFFEEB4FF),
          title: 'Vacaciones próximas',
          value: '${data.upcomingVacations.length}',
          detail: 'Inicios registrados en 15 días',
          chart: _HrDashboardMiniBars(values: data.upcomingVacationTrend),
          onTap: widget.onOpenVacations,
        ),
        _HrDashboardMetricCard(
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFFFBB67),
          title: 'Incidencias abiertas',
          value: data.periodValue(data.openIncidents),
          detail: data.hasPeriod
              ? 'Revisión RH antes del cierre'
              : 'Elige un periodo operativo',
          trailingAction: 'Resolver',
          onTap: widget.onOpenPrenomina,
        ),
      ],
    );
  }

  Widget _operationalInsights(_HrDashboardData data) {
    return _HrDashboardResponsiveGrid(
      minWideColumns: 4,
      children: [
        _HrDashboardCompanyCard(data: data, onTap: widget.onOpenPersonnel),
        _HrDashboardRankCard(
          icon: Icons.schedule_rounded,
          title: 'Más retardos del periodo',
          emptyLabel: data.hasPeriod
              ? 'Sin retardos registrados'
              : 'Elige un periodo operativo',
          rows: data.lateRanking,
          valueLabel: (value) => _hrDashboardHours(value.toInt()),
          onTap: widget.onOpenAttendance,
        ),
        _HrDashboardRankCard(
          icon: Icons.person_off_outlined,
          title: 'Faltas del periodo',
          emptyLabel: data.hasPeriod
              ? 'Sin faltas registradas'
              : 'Elige un periodo operativo',
          rows: data.absenceRanking,
          valueLabel: (value) => '${value.toInt()} día(s)',
          onTap: widget.onOpenAttendance,
        ),
        _HrDashboardPermissionCard(data: data, onTap: widget.onOpenPermissions),
      ],
    );
  }

  Widget _payrollAndVacationInsights(_HrDashboardData data) {
    return _HrDashboardResponsiveGrid(
      minWideColumns: 4,
      children: [
        _HrDashboardMoneyCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Fiscal neto (periodo)',
          amount: data.hasPeriod ? data.payroll.fiscalTotal : null,
          detail: data.hasPeriod
              ? '${data.payroll.rows} colaborador(es) en prenómina'
              : 'Elige un periodo operativo',
          values: data.payrollTrend,
          onTap: widget.onOpenPrenomina,
        ),
        _HrDashboardMoneyCard(
          icon: Icons.payments_outlined,
          title: 'Pago total app (periodo)',
          amount: data.hasPeriod ? data.payroll.visibleTotal : null,
          detail: data.hasPeriod
              ? 'Fiscal, efectivo RH y ajustes visibles'
              : 'Elige un periodo operativo',
          values: data.payrollTrend,
          onTap: widget.onOpenNomina,
          accent: const Color(0xFF63DDAE),
        ),
        _HrDashboardVacationListCard(
          icon: Icons.beach_access_rounded,
          title: 'Vacaciones activas',
          emptyLabel: 'No hay vacaciones activas hoy',
          rows: data.activeVacations,
          onTap: widget.onOpenVacations,
        ),
        _HrDashboardVacationListCard(
          icon: Icons.event_available_outlined,
          title: 'Vacaciones próximas',
          emptyLabel: 'No hay inicios registrados en 15 días',
          rows: data.upcomingVacations,
          onTap: widget.onOpenVacations,
        ),
      ],
    );
  }

  Widget _sectionHeader({required String title, required String detail}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        if (detail.isNotEmpty)
          Expanded(
            child: Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.56),
              ),
            ),
          ),
      ],
    );
  }

  Widget _dashboardErrorCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _HrDashboardPanel(
        accent: const Color(0xFFFFBD78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Color(0xFFFFC27B)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            TextButton(onPressed: _loadData, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _HrDashboardFlowStep {
  final IconData icon;
  final String title;
  final String detail;
  final Future<void> Function() onTap;

  const _HrDashboardFlowStep({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });
}

class _HrDashboardFlowCard extends StatefulWidget {
  final int index;
  final _HrDashboardFlowStep step;

  const _HrDashboardFlowCard({required this.index, required this.step});

  @override
  State<_HrDashboardFlowCard> createState() => _HrDashboardFlowCardState();
}

class _HrDashboardFlowCardState extends State<_HrDashboardFlowCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        scale: _hovered ? 1.02 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async => widget.step.onTap(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              constraints: const BoxConstraints(minHeight: 86),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _hovered
                    ? const Color(0xF43B2362)
                    : const Color(0xEB26163F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _hovered
                      ? const Color(0xFFB78BFF)
                      : const Color(0x805E3A91),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _hovered ? 0.24 : 0.10,
                    ),
                    blurRadius: _hovered ? 18 : 10,
                    offset: Offset(0, _hovered ? 9 : 5),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9F6BFF), Color(0xFF6741BC)],
                      ),
                    ),
                    child: Icon(
                      widget.step.icon,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.index}. ${widget.step.title}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.step.detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.66),
                          ),
                        ),
                      ],
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

class _HrDashboardResponsiveGrid extends StatelessWidget {
  final int minWideColumns;
  final List<Widget> children;

  const _HrDashboardResponsiveGrid({
    required this.minWideColumns,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1280
            ? minWideColumns
            : constraints.maxWidth >= 840
            ? math.min(3, minWideColumns)
            : constraints.maxWidth >= 540
            ? 2
            : 1;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _HrDashboardPanel extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? accent;
  final Future<void> Function()? onTap;

  const _HrDashboardPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent,
    this.onTap,
  });

  @override
  State<_HrDashboardPanel> createState() => _HrDashboardPanelState();
}

class _HrDashboardPanelState extends State<_HrDashboardPanel> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: interactive ? (_) => setState(() => _hovered = true) : null,
      onExit: interactive ? (_) => setState(() => _hovered = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xF4362159) : const Color(0xEC241638),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovered
                ? (widget.accent ?? const Color(0xFFB68CFF)).withValues(
                    alpha: 0.70,
                  )
                : const Color(0x506D4A9C),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovered ? 0.25 : 0.14),
              blurRadius: _hovered ? 20 : 12,
              offset: Offset(0, _hovered ? 10 : 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap == null ? null : () async => widget.onTap!(),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

class _HrDashboardMetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String detail;
  final Widget? chart;
  final String? trailingAction;
  final Future<void> Function()? onTap;

  const _HrDashboardMetricCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.detail,
    this.chart,
    this.trailingAction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _HrDashboardPanel(
      onTap: onTap,
      accent: iconColor,
      child: SizedBox(
        height: 124,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
                if (chart != null)
                  SizedBox(width: 72, height: 54, child: chart!),
              ],
            ),
            if (trailingAction != null) ...[
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$trailingAction  →',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HrDashboardAttendanceCard extends StatelessWidget {
  final _HrDashboardData data;
  final Future<void> Function() onTap;

  const _HrDashboardAttendanceCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _HrDashboardPanel(
      onTap: onTap,
      accent: const Color(0xFF56DDA8),
      child: SizedBox(
        height: 124,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 19,
                  color: Color(0xFF7DE2BA),
                ),
                SizedBox(width: 8),
                Text(
                  'Asistencia del periodo',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                _HrDashboardDonut(
                  size: 78,
                  value: data.attendanceRate,
                  segments: [
                    data.workedDays.toDouble(),
                    data.absenceDays.toDouble(),
                  ],
                  colors: const [Color(0xFF31D8A5), Color(0xFFFF8A6F)],
                  centerLabel: data.hasPeriod
                      ? _hrDashboardPercent(data.attendanceRate)
                      : '—',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HrDashboardLegendLine(
                        color: const Color(0xFF31D8A5),
                        label: 'Laboró',
                        value: data.periodValue(data.workedDays),
                      ),
                      const SizedBox(height: 6),
                      _HrDashboardLegendLine(
                        color: const Color(0xFFFF8A6F),
                        label: 'Faltó',
                        value: data.periodValue(data.absenceDays),
                      ),
                      const SizedBox(height: 6),
                      _HrDashboardLegendLine(
                        color: const Color(0xFFB68CFF),
                        label: 'Retardos',
                        value: data.periodValue(data.lateRecordCount),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HrDashboardLegendLine extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _HrDashboardLegendLine({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _HrDashboardCompanyCard extends StatelessWidget {
  final _HrDashboardData data;
  final Future<void> Function() onTap;

  const _HrDashboardCompanyCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF8B5CF6),
      Color(0xFF3876FF),
      Color(0xFFFF9C39),
      Color(0xFFEC4D8E),
      Color(0xFF37D3A4),
      Color(0xFFAAC1DD),
    ];
    final items = data.companyCounts.entries.toList();
    return _HrDashboardPanel(
      onTap: onTap,
      child: SizedBox(
        height: 204,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 19,
                  color: Color(0xFFC49EFF),
                ),
                SizedBox(width: 8),
                Text(
                  'Empleados por empresa',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: items.isEmpty
                  ? _HrDashboardEmptyLabel(label: 'Sin expedientes registrados')
                  : Row(
                      children: [
                        _HrDashboardDonut(
                          size: 116,
                          value: null,
                          segments: [
                            for (final item in items) item.value.toDouble(),
                          ],
                          colors: [
                            for (var i = 0; i < items.length; i++)
                              colors[i % colors.length],
                          ],
                          centerLabel: '${data.employeeCount}',
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ListView.separated(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: math.min(items.length, 6),
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 7),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final percent = data.employeeCount == 0
                                  ? 0
                                  : item.value / data.employeeCount * 100;
                              return Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: colors[index % colors.length],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.key,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withValues(
                                          alpha: 0.74,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${item.value} (${percent.toStringAsFixed(0)}%)',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrDashboardRankCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String emptyLabel;
  final List<_HrDashboardRankItem> rows;
  final String Function(double value) valueLabel;
  final Future<void> Function() onTap;

  const _HrDashboardRankCard({
    required this.icon,
    required this.title,
    required this.emptyLabel,
    required this.rows,
    required this.valueLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _HrDashboardPanel(
      onTap: onTap,
      child: SizedBox(
        height: 204,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: const Color(0xFFC49EFF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: rows.isEmpty
                  ? _HrDashboardEmptyLabel(label: emptyLabel)
                  : ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: math.min(rows.length, 5),
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4C2B71),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFE2CDFF),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (row.company.isNotEmpty)
                                    Text(
                                      row.company,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withValues(
                                          alpha: 0.54,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              valueLabel(row.value),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFE0CCFF),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Ver detalle  →',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFC49EFF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrDashboardPermissionCard extends StatelessWidget {
  final _HrDashboardData data;
  final Future<void> Function() onTap;

  const _HrDashboardPermissionCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = data.permissionDistribution.entries.toList();
    const colors = [
      Color(0xFF1FC6B1),
      Color(0xFF9056FF),
      Color(0xFFFFA13D),
      Color(0xFFEF70B6),
    ];
    return _HrDashboardPanel(
      onTap: onTap,
      child: SizedBox(
        height: 204,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 19,
                  color: Color(0xFFC49EFF),
                ),
                SizedBox(width: 8),
                Text(
                  'Permisos del periodo',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  data.periodValue(data.permissionEventsCount),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'eventos',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.64),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: items.isEmpty
                  ? _HrDashboardEmptyLabel(
                      label: data.hasPeriod
                          ? 'Sin permisos en el periodo'
                          : 'Elige un periodo operativo',
                    )
                  : Row(
                      children: [
                        _HrDashboardDonut(
                          size: 96,
                          value: null,
                          segments: [
                            for (final item in items) item.value.toDouble(),
                          ],
                          colors: [
                            for (var i = 0; i < items.length; i++)
                              colors[i % colors.length],
                          ],
                          centerLabel: '${data.permissionEventsCount}',
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (
                                var index = 0;
                                index < items.length && index < 4;
                                index++
                              )
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: _HrDashboardLegendLine(
                                    color: colors[index % colors.length],
                                    label: items[index].key,
                                    value: '${items[index].value}',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrDashboardMoneyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final double? amount;
  final String detail;
  final List<double> values;
  final Color accent;
  final Future<void> Function() onTap;

  const _HrDashboardMoneyCard({
    required this.icon,
    required this.title,
    required this.amount,
    required this.detail,
    required this.values,
    required this.onTap,
    this.accent = const Color(0xFFB68CFF),
  });

  @override
  Widget build(BuildContext context) {
    return _HrDashboardPanel(
      onTap: onTap,
      accent: accent,
      child: SizedBox(
        height: 190,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              amount == null ? '—' : _hrDashboardCurrency(amount!),
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.64),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: _HrDashboardMiniBars(values: values, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrDashboardVacationListCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String emptyLabel;
  final List<_HrDashboardVacationItem> rows;
  final Future<void> Function() onTap;

  const _HrDashboardVacationListCard({
    required this.icon,
    required this.title,
    required this.emptyLabel,
    required this.rows,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _HrDashboardPanel(
      onTap: onTap,
      accent: const Color(0xFF5FE1AE),
      child: SizedBox(
        height: 190,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: const Color(0xFF6CE0B1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: rows.isEmpty
                  ? _HrDashboardEmptyLabel(label: emptyLabel)
                  : ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: math.min(rows.length, 5),
                      separatorBuilder: (_, _) => const SizedBox(height: 7),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                row.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              row.company,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.58),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              row.dateLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFD8C0FF),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Ver vacaciones  →',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFC49EFF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrDashboardEmptyLabel extends StatelessWidget {
  final String label;

  const _HrDashboardEmptyLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.54),
        ),
      ),
    );
  }
}

class _HrDashboardMiniBars extends StatelessWidget {
  final List<num> values;
  final Color color;

  const _HrDashboardMiniBars({
    required this.values,
    this.color = const Color(0xFF9F6BFF),
  });

  @override
  Widget build(BuildContext context) {
    final meaningful = values
        .where((value) => value > 0)
        .map((value) => value.toDouble())
        .toList(growable: false);
    if (meaningful.isEmpty) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 2,
          color: Colors.white.withValues(alpha: 0.13),
        ),
      );
    }
    final maximum = meaningful.reduce(
      (currentMaximum, value) =>
          value > currentMaximum ? value : currentMaximum,
    );
    final visible = meaningful.length > 8
        ? meaningful.sublist(meaningful.length - 8)
        : meaningful;
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = math
            .max(
              4.0,
              (constraints.maxWidth - (visible.length - 1) * 4) /
                  visible.length,
            )
            .toDouble();
        return Align(
          alignment: Alignment.bottomCenter,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final value in visible) ...[
                Container(
                  width: barWidth,
                  height: math
                      .max(5.0, constraints.maxHeight * value / maximum)
                      .toDouble(),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.88),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.28),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                if (value != visible.last) const SizedBox(width: 4),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HrDashboardDonut extends StatelessWidget {
  final double size;
  final double? value;
  final List<double> segments;
  final List<Color> colors;
  final String centerLabel;

  const _HrDashboardDonut({
    required this.size,
    required this.value,
    required this.segments,
    required this.colors,
    required this.centerLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _HrDashboardDonutPainter(
              segments: segments,
              colors: colors,
            ),
          ),
          Text(
            centerLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _HrDashboardDonutPainter extends CustomPainter {
  final List<double> segments;
  final List<Color> colors;

  const _HrDashboardDonutPainter({
    required this.segments,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Offset.zero & size;
    final background = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect.deflate(stroke / 2), 0, math.pi * 2, false, background);
    final total = segments.fold<double>(0, (sum, item) => sum + item);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (var index = 0; index < segments.length; index++) {
      final sweep = math.pi * 2 * (segments[index] / total);
      if (sweep <= 0) continue;
      final paint = Paint()
        ..color = colors[index % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        rect.deflate(stroke / 2),
        start,
        math.max(0, sweep - 0.04),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _HrDashboardDonutPainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.colors != colors;
}

class _HrDashboardRoundAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Future<void> Function()? onTap;

  const _HrDashboardRoundAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap == null ? null : () async => onTap!(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xE826183E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x806D4A9C)),
            ),
            child: Icon(icon, size: 19, color: const Color(0xFFCBA7FF)),
          ),
        ),
      ),
    );
  }
}

class _HrDashboardData {
  final bool loaded;
  final List<String> periodOptions;
  final String activePeriodLabel;
  final int employeeCount;
  final Map<String, int> companyCounts;
  final bool hasNgtEco;
  final bool hasContpaq;
  final int workedDays;
  final int absenceDays;
  final int lateRecordCount;
  final int lateMinutes;
  final int overtimeMinutes;
  final List<_HrDashboardRankItem> lateRanking;
  final List<_HrDashboardRankItem> absenceRanking;
  final int permissionEventsCount;
  final int permissionPendingCount;
  final Map<String, int> permissionDistribution;
  final int openIncidents;
  final int activeVacationEmployees;
  final List<_HrDashboardVacationItem> activeVacations;
  final List<_HrDashboardVacationItem> upcomingVacations;
  final List<double> activeVacationTrend;
  final List<double> upcomingVacationTrend;
  final _HrDashboardPayroll payroll;
  final List<double> payrollTrend;
  final int prenominaReadyCount;
  final int prenominaReviewCount;
  final bool payrollClosed;

  const _HrDashboardData({
    required this.loaded,
    required this.periodOptions,
    required this.activePeriodLabel,
    required this.employeeCount,
    required this.companyCounts,
    required this.hasNgtEco,
    required this.hasContpaq,
    required this.workedDays,
    required this.absenceDays,
    required this.lateRecordCount,
    required this.lateMinutes,
    required this.overtimeMinutes,
    required this.lateRanking,
    required this.absenceRanking,
    required this.permissionEventsCount,
    required this.permissionPendingCount,
    required this.permissionDistribution,
    required this.openIncidents,
    required this.activeVacationEmployees,
    required this.activeVacations,
    required this.upcomingVacations,
    required this.activeVacationTrend,
    required this.upcomingVacationTrend,
    required this.payroll,
    required this.payrollTrend,
    required this.prenominaReadyCount,
    required this.prenominaReviewCount,
    required this.payrollClosed,
  });

  const _HrDashboardData.empty()
    : loaded = false,
      periodOptions = const [],
      activePeriodLabel = '',
      employeeCount = 0,
      companyCounts = const {},
      hasNgtEco = false,
      hasContpaq = false,
      workedDays = 0,
      absenceDays = 0,
      lateRecordCount = 0,
      lateMinutes = 0,
      overtimeMinutes = 0,
      lateRanking = const [],
      absenceRanking = const [],
      permissionEventsCount = 0,
      permissionPendingCount = 0,
      permissionDistribution = const {},
      openIncidents = 0,
      activeVacationEmployees = 0,
      activeVacations = const [],
      upcomingVacations = const [],
      activeVacationTrend = const [],
      upcomingVacationTrend = const [],
      payroll = const _HrDashboardPayroll.empty(),
      payrollTrend = const [],
      prenominaReadyCount = 0,
      prenominaReviewCount = 0,
      payrollClosed = false;

  bool get hasPeriod => activePeriodLabel.isNotEmpty;
  double? get attendanceRate {
    final total = workedDays + absenceDays;
    return total == 0 ? null : workedDays / total;
  }

  String get importStatus {
    if (!hasPeriod) return 'Selecciona un periodo';
    if (hasNgtEco && hasContpaq) return 'NGTeco y CONTPAQ listos';
    if (hasNgtEco) return 'Falta CONTPAQ';
    if (hasContpaq) return 'Falta NGTeco';
    return 'Sin archivos del periodo';
  }

  String get attendanceFlowDetail => hasPeriod
      ? '${workedDays + absenceDays} jornadas registradas'
      : 'Selecciona un periodo';
  String get permissionFlowDetail => hasPeriod
      ? '$permissionEventsCount evento(s) del periodo'
      : 'Selecciona un periodo';
  String get prenominaFlowDetail => hasPeriod
      ? '$prenominaReadyCount lista(s) · $prenominaReviewCount revisión'
      : 'Selecciona un periodo';
  String get nominaFlowDetail => !hasPeriod
      ? 'Selecciona un periodo'
      : payrollClosed
      ? 'Cierre confirmado'
      : 'Pendiente de cierre';
  String get periodDescription => hasPeriod
      ? activePeriodLabel
      : periodOptions.isEmpty
      ? 'Aún no hay periodos importados'
      : 'Selecciona el periodo que deseas consultar';

  String periodValue(int value) => hasPeriod ? '$value' : '—';

  factory _HrDashboardData.fromRows({
    required String selectedPeriodLabel,
    required List<Map<String, dynamic>> profiles,
    required List<Map<String, dynamic>> importLots,
    required List<Map<String, dynamic>> attendanceRecords,
    required List<Map<String, dynamic>> vacationEvents,
    required List<Map<String, dynamic>> permissionEvents,
    required List<Map<String, dynamic>> prenominaDrafts,
    required List<Map<String, dynamic>> periodClosures,
  }) {
    final peopleById = <String, _HrDashboardPerson>{};
    final companyCounts = <String, int>{};
    for (final row in profiles) {
      final id = (row['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      final name = (row['nombre'] ?? '').toString().trim();
      final company = (row['empresa'] ?? '').toString().trim();
      peopleById[id] = _HrDashboardPerson(
        id: id,
        name: name.isEmpty ? 'ID #$id' : name,
        company: company,
      );
      final key = company.isEmpty ? 'Sin empresa' : company;
      companyCounts[key] = (companyCounts[key] ?? 0) + 1;
    }
    final sortedCompanies = companyCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final orderedCompanyCounts = <String, int>{
      for (final entry in sortedCompanies) entry.key: entry.value,
    };

    final labels = <String>[
      for (final row in importLots) _hrDashboardDescribeImportPeriod(row),
      for (final row in attendanceRecords)
        (row['period_label'] ?? '').toString(),
      for (final row in vacationEvents)
        (row['attendance_period_label'] ?? '').toString(),
      for (final row in permissionEvents)
        (row['attendance_period_label'] ?? '').toString(),
      for (final row in prenominaDrafts) (row['period_label'] ?? '').toString(),
      for (final row in periodClosures) (row['period_label'] ?? '').toString(),
    ];
    final periodOptions = HumanResourcesPeriodContext.normalizedOptions(labels);
    final activePeriod = HumanResourcesPeriodContext.resolveSelected(
      selectedLabel: selectedPeriodLabel,
      availableLabels: periodOptions,
    );
    final periodRange = HumanResourcesPeriodRange.tryParse(activePeriod);
    bool eventBelongsToPeriod(Map<String, dynamic> row) {
      if (activePeriod.isEmpty) return false;
      if ((row['attendance_period_label'] ?? '').toString() == activePeriod) {
        return true;
      }
      if (periodRange == null) return false;
      final start = _hrDashboardParseDate(row['start_date']);
      final end = _hrDashboardParseDate(row['end_date']) ?? start;
      if (start == null || end == null) return false;
      return !end.isBefore(periodRange.start) &&
          !start.isAfter(periodRange.end);
    }

    final activeAttendance = attendanceRecords
        .where((row) => (row['period_label'] ?? '').toString() == activePeriod)
        .toList(growable: false);
    final workedDays = activeAttendance
        .where((row) => row['status'] == 'laboro')
        .length;
    final absenceDays = activeAttendance
        .where((row) => row['status'] == 'falto')
        .length;
    final lateRecords = activeAttendance
        .where((row) => _hrDashboardNumber(row['late_minutes']) > 0)
        .toList(growable: false);
    final lateMinutes = lateRecords.fold<int>(
      0,
      (total, row) => total + _hrDashboardNumber(row['late_minutes']).round(),
    );
    final overtimeMinutes = activeAttendance.fold<int>(
      0,
      (total, row) =>
          total + _hrDashboardNumber(row['overtime_minutes']).round(),
    );
    final lateRanking = _hrDashboardBuildRanking(
      rows: lateRecords,
      peopleById: peopleById,
      valueForRow: (row) => _hrDashboardNumber(row['late_minutes']),
    );
    final absenceRanking = _hrDashboardBuildRanking(
      rows: activeAttendance.where((row) => row['status'] == 'falto'),
      peopleById: peopleById,
      valueForRow: (_) => 1,
    );

    final activePermissions = permissionEvents
        .where(
          (row) => eventBelongsToPeriod(row) && row['status'] != 'cancelado',
        )
        .toList(growable: false);
    final permissionDistribution = <String, int>{};
    for (final row in activePermissions) {
      final label = _hrDashboardPermissionLabel(
        (row['permission_type'] ?? '').toString(),
      );
      permissionDistribution[label] = (permissionDistribution[label] ?? 0) + 1;
    }
    final pendingPermissions = activePermissions
        .where((row) => row['status'] == 'pendiente')
        .length;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final futureLimit = todayDate.add(const Duration(days: 15));
    final validVacations = vacationEvents
        .where(
          (row) =>
              row['status'] != 'cancelado' &&
              (row['event_type'] == 'vacaciones_disfrutadas' ||
                  row['event_type'] == 'vacaciones_pendientes'),
        )
        .toList(growable: false);
    final activeVacationRows = validVacations
        .where((row) {
          final start = _hrDashboardParseDate(row['start_date']);
          final end = _hrDashboardParseDate(row['end_date']) ?? start;
          return start != null &&
              end != null &&
              !start.isAfter(todayDate) &&
              !end.isBefore(todayDate);
        })
        .toList(growable: false);
    final upcomingVacationRows =
        validVacations
            .where((row) {
              final start = _hrDashboardParseDate(row['start_date']);
              return start != null &&
                  start.isAfter(todayDate) &&
                  !start.isAfter(futureLimit);
            })
            .toList(growable: false)
          ..sort(
            (a, b) => _hrDashboardParseDate(
              a['start_date'],
            )!.compareTo(_hrDashboardParseDate(b['start_date'])!),
          );
    _HrDashboardVacationItem vacationItem(Map<String, dynamic> row) {
      final id = (row['employee_id'] ?? '').toString();
      final person = peopleById[id];
      final name = (row['employee_name'] ?? '').toString().trim();
      return _HrDashboardVacationItem(
        name: name.isEmpty ? (person?.name ?? 'ID #$id') : name,
        company: person?.company ?? '',
        date: _hrDashboardParseDate(row['start_date']) ?? todayDate,
      );
    }

    final activeVacations = activeVacationRows
        .map(vacationItem)
        .toList(growable: false);
    final upcomingVacations = upcomingVacationRows
        .map(vacationItem)
        .toList(growable: false);

    final activeDrafts = prenominaDrafts
        .where((row) => (row['period_label'] ?? '').toString() == activePeriod)
        .toList(growable: false);
    final payroll = _HrDashboardPayroll.fromRows(activeDrafts);
    final readyCount = activeDrafts
        .where(
          (row) =>
              row['draft_status'] == 'listo' ||
              row['draft_status'] == 'publicado',
        )
        .length;
    final reviewCount = activeDrafts
        .where(
          (row) =>
              row['draft_status'] == 'revision_rh' ||
              row['draft_status'] == 'borrador',
        )
        .length;
    final pendingVacations = vacationEvents
        .where(
          (row) => eventBelongsToPeriod(row) && row['status'] == 'pendiente',
        )
        .length;
    final closed = periodClosures.any(
      (row) =>
          (row['period_label'] ?? '').toString() == activePeriod &&
          row['status'] == 'cerrado',
    );

    final payrollByPeriod = <String, List<Map<String, dynamic>>>{};
    for (final row in prenominaDrafts) {
      final label = (row['period_label'] ?? '').toString().trim();
      if (label.isEmpty) continue;
      payrollByPeriod.putIfAbsent(label, () => []).add(row);
    }
    final payrollLabels = payrollByPeriod.keys.toList()
      ..sort((a, b) {
        final aDate = HumanResourcesPeriodRange.tryParse(a)?.end;
        final bDate = HumanResourcesPeriodRange.tryParse(b)?.end;
        if (aDate != null && bDate != null) return aDate.compareTo(bDate);
        return a.compareTo(b);
      });
    final payrollTrend = [
      for (final label in payrollLabels)
        _HrDashboardPayroll.fromRows(payrollByPeriod[label]!).visibleTotal,
    ];

    final importedSources = <String>{
      for (final lot in importLots)
        if (_hrDashboardDescribeImportPeriod(lot) == activePeriod)
          (lot['source'] ?? '').toString().toLowerCase(),
    };
    return _HrDashboardData(
      loaded: true,
      periodOptions: periodOptions,
      activePeriodLabel: activePeriod,
      employeeCount: peopleById.length,
      companyCounts: orderedCompanyCounts,
      hasNgtEco: importedSources.contains('ngteco'),
      hasContpaq: importedSources.contains('contpaq'),
      workedDays: workedDays,
      absenceDays: absenceDays,
      lateRecordCount: lateRecords.length,
      lateMinutes: lateMinutes,
      overtimeMinutes: overtimeMinutes,
      lateRanking: lateRanking,
      absenceRanking: absenceRanking,
      permissionEventsCount: activePermissions.length,
      permissionPendingCount: pendingPermissions,
      permissionDistribution: permissionDistribution,
      openIncidents: pendingPermissions + pendingVacations + reviewCount,
      activeVacationEmployees: activeVacationRows
          .map((row) => row['employee_id'])
          .toSet()
          .length,
      activeVacations: activeVacations,
      upcomingVacations: upcomingVacations,
      activeVacationTrend: _hrDashboardVacationDayTrend(
        activeVacationRows,
        todayDate,
      ),
      upcomingVacationTrend: _hrDashboardVacationDayTrend(
        upcomingVacationRows,
        todayDate,
      ),
      payroll: payroll,
      payrollTrend: payrollTrend,
      prenominaReadyCount: readyCount,
      prenominaReviewCount: reviewCount,
      payrollClosed: closed,
    );
  }
}

class _HrDashboardPerson {
  final String id;
  final String name;
  final String company;

  const _HrDashboardPerson({
    required this.id,
    required this.name,
    required this.company,
  });
}

class _HrDashboardRankItem {
  final String name;
  final String company;
  final double value;

  const _HrDashboardRankItem({
    required this.name,
    required this.company,
    required this.value,
  });
}

class _HrDashboardVacationItem {
  final String name;
  final String company;
  final DateTime date;

  const _HrDashboardVacationItem({
    required this.name,
    required this.company,
    required this.date,
  });

  String get dateLabel => _hrDashboardDateLabel(date);
}

class _HrDashboardPayroll {
  final int rows;
  final double fiscalTotal;
  final double visibleTotal;

  const _HrDashboardPayroll({
    required this.rows,
    required this.fiscalTotal,
    required this.visibleTotal,
  });

  const _HrDashboardPayroll.empty()
    : rows = 0,
      fiscalTotal = 0,
      visibleTotal = 0;

  factory _HrDashboardPayroll.fromRows(List<Map<String, dynamic>> rows) {
    var fiscal = 0.0;
    var visible = 0.0;
    for (final row in rows) {
      final fiscalNet = _hrDashboardNumber(row['fiscal_net_amount']);
      final late = _hrDashboardNumber(row['fiscal_late_deduction_amount']);
      final fiscalVacation = _hrDashboardNumber(row['fiscal_vacation_amount']);
      final fiscalRow = math.max(0.0, fiscalNet - late) + fiscalVacation;
      final cashIncome =
          _hrDashboardNumber(row['cash_salary_amount']) +
          _hrDashboardNumber(row['cash_vacation_amount']) +
          _hrDashboardNumber(row['transport_support_amount']) +
          _hrDashboardNumber(row['holiday_amount']) +
          _hrDashboardNumber(row['overtime_monetized_amount']) +
          _hrDashboardNumber(row['manual_bonus_amount']);
      final cashDeductions =
          _hrDashboardNumber(row['cash_isr_amount']) +
          _hrDashboardNumber(row['cash_absence_deduction_amount']) +
          _hrDashboardNumber(row['cash_infonavit_deduction_amount']) +
          _hrDashboardNumber(row['cash_fonacot_deduction_amount']) +
          _hrDashboardNumber(row['loan_deduction_amount']);
      fiscal += fiscalRow;
      visible +=
          fiscalRow +
          cashIncome -
          cashDeductions +
          _hrDashboardNumber(row['manual_adjustment_amount']) +
          _hrDashboardNumber(row['payment_outside_amount']);
    }
    return _HrDashboardPayroll(
      rows: rows.length,
      fiscalTotal: fiscal,
      visibleTotal: visible,
    );
  }
}

List<_HrDashboardRankItem> _hrDashboardBuildRanking({
  required Iterable<Map<String, dynamic>> rows,
  required Map<String, _HrDashboardPerson> peopleById,
  required double Function(Map<String, dynamic> row) valueForRow,
}) {
  final values = <String, double>{};
  final names = <String, String>{};
  for (final row in rows) {
    final id = (row['employee_id'] ?? '').toString();
    if (id.isEmpty) continue;
    values[id] = (values[id] ?? 0) + valueForRow(row);
    final name = (row['employee_name'] ?? '').toString().trim();
    if (name.isNotEmpty) names[id] = name;
  }
  final ranking = [
    for (final entry in values.entries)
      _HrDashboardRankItem(
        name:
            names[entry.key] ??
            peopleById[entry.key]?.name ??
            'ID #${entry.key}',
        company: peopleById[entry.key]?.company ?? '',
        value: entry.value,
      ),
  ];
  ranking.sort((a, b) => b.value.compareTo(a.value));
  return ranking;
}

List<double> _hrDashboardVacationDayTrend(
  List<Map<String, dynamic>> rows,
  DateTime reference,
) {
  final counts = <int, int>{};
  for (final row in rows) {
    final start = _hrDashboardParseDate(row['start_date']);
    if (start == null) continue;
    final offset = start.difference(reference).inDays;
    counts[offset] = (counts[offset] ?? 0) + 1;
  }
  return [for (var day = 0; day < 7; day++) (counts[day] ?? 0).toDouble()];
}

String _hrDashboardDescribeImportPeriod(Map<String, dynamic> row) {
  final raw = (row['period_label'] ?? '').toString().trim();
  if (raw.isEmpty) return '';
  final source = (row['source'] ?? '').toString().toLowerCase();
  if (source == 'ngteco') {
    final segments = raw.split('→').map((item) => item.trim()).toList();
    if (segments.length == 2) {
      final first = _hrDashboardParseUsDate(segments.first);
      final second = _hrDashboardParseUsDate(segments.last);
      if (first != null && second != null) {
        final dates = [first, second]..sort();
        return '${_hrDashboardDateLabel(dates.first)} - ${_hrDashboardDateLabel(dates.last)}';
      }
    }
    return raw;
  }
  final match = RegExp(
    r'Periodo\s+(\d+)\s+al\s+\d+\s+Semanal\s+del\s+(\d{2}/\d{2}/\d{4})\s+al\s+(\d{2}/\d{2}/\d{4})(?:\s+·\s+Hora:\s+(\d{2}:\d{2}:\d{2}))?',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return raw;
  final week = match.group(1)!;
  final time = match.group(4);
  final base = 'Periodo $week semanal · ${match.group(2)} - ${match.group(3)}';
  return time == null ? base : '$base · Archivo $time';
}

DateTime? _hrDashboardParseUsDate(String raw) {
  final parts = raw.split('/');
  if (parts.length != 3) return null;
  final month = int.tryParse(parts[0]);
  final day = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (month == null || day == null || year == null) return null;
  return DateTime(year, month, day);
}

DateTime? _hrDashboardParseDate(Object? value) {
  final raw = (value ?? '').toString().trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

double _hrDashboardNumber(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString().replaceAll(',', '')) ?? 0;
}

String _hrDashboardPermissionLabel(String raw) {
  switch (raw) {
    case 'permiso_con_goce':
      return 'Con goce';
    case 'permiso_sin_goce':
      return 'Sin goce';
    case 'incapacidad':
      return 'Incapacidad';
    case 'ajuste_rh':
      return 'Ajuste RH';
    default:
      return 'Otros';
  }
}

String _hrDashboardDateLabel(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

String _hrDashboardPercent(double? value) {
  if (value == null) return '—';
  return '${(value * 100).toStringAsFixed(1)}%';
}

String _hrDashboardHours(int minutes) =>
    '${(minutes / 60).toStringAsFixed(2)} h';

String _hrDashboardCurrency(double value) {
  final fixed = value.toStringAsFixed(2).split('.');
  final whole = fixed.first.replaceAllMapped(
    RegExp(r'(?<!^)(?=(\d{3})+$)'),
    (_) => ',',
  );
  return '\$$whole.${fixed.last}';
}
