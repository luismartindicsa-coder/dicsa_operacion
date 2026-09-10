import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/archetypes/auxiliary_surfaces/searchable_picker.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/file_download_save.dart';
import 'human_resources_area_chrome.dart';
import 'human_resources_attendance_incidents_page.dart';
import 'human_resources_attendance_page.dart';
import 'human_resources_compensation.dart';
import 'human_resources_dashboard_page.dart';
import 'human_resources_nomina_page.dart';
import 'human_resources_loans_page.dart';
import 'human_resources_permissions_page.dart';
import 'human_resources_personnel_page.dart';
import 'human_resources_prenomina_page.dart';
import 'human_resources_termination_calculation.dart';
import 'human_resources_theme.dart';
import 'human_resources_vacations_page.dart';
import 'termination/termination_pdf.dart';
import 'termination/termination_repository.dart';

part 'termination/termination_editor.dart';

class HumanResourcesTerminationsPage extends StatefulWidget {
  final bool instantOpen;
  const HumanResourcesTerminationsPage({super.key, this.instantOpen = false});
  @override
  State<HumanResourcesTerminationsPage> createState() =>
      _TerminationsPageState();
}

class _TerminationsPageState extends State<HumanResourcesTerminationsPage> {
  late final _repository = HrTerminationRepository(Supabase.instance.client);
  final _editorKey = GlobalKey<_TerminationEditorState>();
  List<Map<String, dynamic>> _employees = [];
  Map<String, dynamic>? _employee;
  Map<String, List<Map<String, dynamic>>> _antecedents = {};
  String? _error;
  String? _antecedentsError;
  bool _loading = true;
  bool _menuOpen = false;
  bool _canReturnToDirection = false;
  bool _dirty = false;
  bool _editorBusy = false;
  int _employeeRequest = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final profile = await AuthAccess.resolveCurrentProfile();
      if (!AuthAccess.hasHumanResourcesAccess(profile)) {
        throw StateError('Tu perfil no tiene acceso a Recursos Humanos.');
      }
      final employees = await _repository.employees();
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _canReturnToDirection = AuthAccess.canAccessGeneralDashboard(profile);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<bool> _canLeave() async {
    if (_editorBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Espera a que termine la operación actual.'),
        ),
      );
      return false;
    }
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AreaThemeScope(
            tokens: humanResourcesAreaTokens,
            child: ContractDialogShell(
              child: SizedBox(
                width: 480,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cambios sin guardar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Guarda una versión para conservar este cálculo. ¿Descartar los cambios?',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Seguir editando'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Descartar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ) ??
        false;
  }

  Future<void> _chooseEmployee() async {
    if (!await _canLeave() || !mounted) return;
    final selected = await showSearchablePickerDialog<String>(
      context,
      title: 'Buscar colaborador',
      initialValue: _employee?['id']?.toString(),
      options: [
        for (final e in _employees)
          SearchablePickerOption(
            value: e['id'].toString(),
            label:
                '${e['nombre']} · ${e['id']} · ${e['empresa']} · ${e['employment_status']}',
          ),
      ],
    );
    if (selected == null || !mounted) return;
    final request = ++_employeeRequest;
    final employee = _employees.firstWhere(
      (e) => e['id'].toString() == selected,
    );
    setState(() {
      _employee = employee;
      _antecedents = {};
      _antecedentsError = null;
      _dirty = false;
    });
    try {
      final antecedents = await _repository.antecedents(selected);
      if (mounted && request == _employeeRequest) {
        setState(() => _antecedents = antecedents);
      }
    } catch (e) {
      if (mounted && request == _employeeRequest) {
        setState(
          () => _antecedentsError =
              'No se pudieron consultar los antecedentes: $e',
        );
      }
    }
  }

  Future<void> _navigate(Widget page, {bool replace = true}) async {
    if (!await _canLeave() || !mounted) return;
    setState(() {
      _dirty = false;
      _menuOpen = false;
    });
    if (replace) {
      await Navigator.of(context).pushReplacement(appPageRoute(page: page));
    } else {
      await Navigator.of(context).push(appPageRoute(page: page));
    }
  }

  @override
  Widget build(BuildContext context) => AreaThemeScope(
    tokens: humanResourcesAreaTokens,
    child: PopScope(
      canPop: !_dirty && !_editorBusy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !await _canLeave() || !mounted) return;
        setState(() => _dirty = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      },
      child: AppShell(
        background: const HumanResourcesAreaBackground(),
        wrapBodyInGlass: false,
        animateHeaderSlots: false,
        animateBody: !widget.instantOpen,
        headerBodySpacing: 8,
        minContentWidth: 900,
        padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
        leadingBuilder: (_, _) => HumanResourcesAreaHeaderButton(
          label: _menuOpen ? 'Cerrar panel' : 'Navegación',
          icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
          onTapSync: () => setState(() => _menuOpen = !_menuOpen),
        ),
        centerBuilder: (_, _) => const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DicsaLogoD(size: 54),
            SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recursos Humanos',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  Text(
                    'Finiquitos',
                    style: TextStyle(
                      color: Color(0xFFC79CFF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        trailingBuilder: (_, _) => HumanResourcesAreaHeaderButton(
          label: 'Cerrar sesión',
          icon: Icons.logout_rounded,
          onTap: () async {
            if (await _canLeave() && context.mounted) {
              await signOutAndRouteToLogin(context);
            }
          },
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1540),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Finiquitos y separación laboral',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _chooseEmployee,
                                icon: const Icon(Icons.person_search_rounded),
                                label: const Text('Buscar colaborador'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: _employee == null
                                ? const ContractGlassCard(
                                    child: Center(
                                      child: Text(
                                        'Selecciona un colaborador para calcular su finiquito, liquidación o indemnización.',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                        ),
                                      ),
                                    ),
                                  )
                                : HrTerminationEditor(
                                    key: _editorKey,
                                    employee: _employee!,
                                    antecedents: _antecedents,
                                    antecedentsError: _antecedentsError,
                                    onSave: _repository.save,
                                    onBusy: (busy) {
                                      if (mounted) {
                                        setState(() => _editorBusy = busy);
                                      }
                                    },
                                    onHistory: () => _repository.history(
                                      _employee!['id'].toString(),
                                    ),
                                    onDirty: (dirty) {
                                      if (mounted) {
                                        setState(() => _dirty = dirty);
                                      }
                                    },
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
            HumanResourcesAreaNavigationOverlay(
              menuOpen: _menuOpen,
              onDismiss: () => setState(() => _menuOpen = false),
              canReturnToDirection: _canReturnToDirection,
              sections: buildHumanResourcesAreaSections(
                activeScreen: HumanResourcesAreaScreen.terminations,
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
                openTerminations: () async {},
                openLoans: () =>
                    _navigate(const HumanResourcesLoansPage(instantOpen: true)),
              ),
              accessItems: buildHumanResourcesAccessItems(
                activeScreen: HumanResourcesAreaScreen.terminations,
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
