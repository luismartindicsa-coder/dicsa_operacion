import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/refresh/lifecycle_refresh_scope.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'human_resources_area_chrome.dart';
import 'human_resources_attendance_incidents_page.dart';
import 'human_resources_attendance_page.dart';
import 'human_resources_dashboard_page.dart';
import 'human_resources_documentation_page.dart';
import 'human_resources_loans_page.dart';
import 'human_resources_nomina_page.dart';
import 'human_resources_permissions_page.dart';
import 'human_resources_personnel_page.dart';
import 'human_resources_prenomina_page.dart';
import 'human_resources_terminations_page.dart';
import 'human_resources_theme.dart';
import 'human_resources_vacations_page.dart';
import 'personnel/hr_job_positions.dart';
import 'vacancies/hr_staffing.dart';
import 'vacancies/hr_staffing_editor.dart';
import 'vacancies/hr_staffing_workspace.dart';
import 'vacancies/hr_vacancy_alerts.dart';

class HumanResourcesVacanciesPage extends StatefulWidget {
  final bool instantOpen;
  const HumanResourcesVacanciesPage({super.key, this.instantOpen = false});
  @override
  State<HumanResourcesVacanciesPage> createState() =>
      _HumanResourcesVacanciesPageState();
}

class _HumanResourcesVacanciesPageState
    extends State<HumanResourcesVacanciesPage> {
  late final _repository = HrStaffingRepository(Supabase.instance.client);
  HrStaffingSnapshot? _snapshot;
  String? _error;
  bool _refreshing = false,
      _editing = false,
      _menuOpen = false,
      _canReturnToDirection = false,
      _reloadPending = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    hrStaffingChanges.addListener(_changed);
    _changed();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _changed());
  }

  @override
  void dispose() {
    _timer?.cancel();
    hrStaffingChanges.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (_editing || _refreshing) {
      _reloadPending = true;
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_editing || _refreshing) {
      _reloadPending = true;
      return;
    }
    _refreshing = true;
    _reloadPending = false;
    try {
      final profile = await AuthAccess.resolveCurrentProfile();
      if (!AuthAccess.hasHumanResourcesAccess(profile)) {
        if (mounted) setState(() => _snapshot = null);
        throw StateError('Tu perfil no tiene acceso a Vacantes RH.');
      }
      final snapshot = await _repository.load();
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _error = null;
          _canReturnToDirection = AuthAccess.canAccessGeneralDashboard(profile);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError ? e.message : hrStaffingError(e),
        );
      }
    } finally {
      _refreshing = false;
      if (_reloadPending && mounted && !_editing) unawaited(_load());
    }
  }

  Future<void> _edit(List<HrStaffingTarget> targets) async {
    if (_editing || _snapshot == null || _error != null) return;
    _editing = true;
    final jobs = HrJobPositionRepository(Supabase.instance.client);
    try {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AreaThemeScope(
          tokens: humanResourcesAreaTokens,
          child: HrStaffingEditor(
            targets: targets,
            companies: _snapshot!.companies,
            loadPositions: jobs.load,
            createPosition: jobs.create,
            onSave: _repository.save,
          ),
        ),
      );
    } finally {
      _editing = false;
    }
    if (mounted) await _load();
  }

  Future<void> _navigate(Widget page) async {
    if (_editing) return;
    await Navigator.of(context).pushReplacement(appPageRoute(page: page));
  }

  @override
  Widget build(BuildContext context) => AreaThemeScope(
    tokens: humanResourcesAreaTokens,
    child: LifecycleRefreshScope(
      onResume: _load,
      child: AppShell(
        background: const HumanResourcesAreaBackground(),
        wrapBodyInGlass: false,
        animateHeaderSlots: false,
        animateBody: !widget.instantOpen,
        headerBodySpacing: 8,
        headerCenterSidePadding: 220,
        minContentWidth: 900,
        padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
        leadingBuilder: (_, _) => HumanResourcesAreaHeaderButton(
          label: _menuOpen ? 'Cerrar panel' : 'Navegación',
          icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
          onTapSync: () => setState(() => _menuOpen = !_menuOpen),
        ),
        centerBuilder: (_, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DicsaLogoD(size: 54),
            const SizedBox(width: 12),
            Text(
              'Vacantes RH',
              style: TextStyle(
                color: humanResourcesAreaTokens.onGlass,
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        trailingBuilder: (_, _) => HumanResourcesAreaHeaderButton(
          label: 'Cerrar sesión',
          icon: Icons.logout_rounded,
          onTap: () => signOutAndRouteToLogin(context),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'No se pudieron actualizar las vacantes: $_error',
                      style: TextStyle(color: humanResourcesAreaTokens.onGlass),
                    ),
                  ),
                Expanded(
                  child: _snapshot == null
                      ? Center(
                          child: _error == null
                              ? const CircularProgressIndicator()
                              : Text(
                                  'La consulta se reintentará automáticamente.',
                                  style: TextStyle(
                                    color: humanResourcesAreaTokens.badgeText,
                                  ),
                                ),
                        )
                      : HrStaffingWorkspace(
                          snapshot: _snapshot!,
                          onEdit: _error == null ? _edit : null,
                          pendingButton: HrVacancyPendingButton(
                            load: _repository.load,
                          ),
                        ),
                ),
              ],
            ),
            HumanResourcesAreaNavigationOverlay(
              menuOpen: _menuOpen,
              onDismiss: () => setState(() => _menuOpen = false),
              canReturnToDirection: _canReturnToDirection,
              sections: buildHumanResourcesAreaSections(
                activeScreen: HumanResourcesAreaScreen.vacancies,
                openPersonnel: () => _navigate(
                  const HumanResourcesPersonnelPage(instantOpen: true),
                ),
                openAttendance: () => _navigate(
                  const HumanResourcesAttendancePage(instantOpen: true),
                ),
                openImportConciliation: () => _navigate(
                  const HumanResourcesAttendanceIncidentsPage(
                    instantOpen: true,
                  ),
                ),
                openVacations: () => _navigate(
                  const HumanResourcesVacationsPage(instantOpen: true),
                ),
                openPermissions: () => _navigate(
                  const HumanResourcesPermissionsPage(instantOpen: true),
                ),
                openPrenomina: () => _navigate(
                  const HumanResourcesPrenominaPage(instantOpen: true),
                ),
                openNomina: () => _navigate(
                  const HumanResourcesNominaPage(instantOpen: true),
                ),
                openTerminations: () => _navigate(
                  const HumanResourcesTerminationsPage(instantOpen: true),
                ),
                openLoans: () =>
                    _navigate(const HumanResourcesLoansPage(instantOpen: true)),
                openDocumentation: () => _navigate(
                  const HumanResourcesDocumentationPage(instantOpen: true),
                ),
                openVacancies: () async {},
              ),
              accessItems: buildHumanResourcesAccessItems(
                activeScreen: HumanResourcesAreaScreen.vacancies,
                openDashboard: () => _navigate(
                  const HumanResourcesDashboardPage(instantOpen: true),
                ),
                canReturnToDirection: _canReturnToDirection,
                openDirectionDashboard: () =>
                    _navigate(const GeneralDashboardPage(instantOpen: true)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
