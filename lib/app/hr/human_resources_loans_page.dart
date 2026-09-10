import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shared/utils/number_formatters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/archetypes/auxiliary_surfaces/date_picker_surface.dart';
import '../shared/archetypes/auxiliary_surfaces/searchable_picker.dart';
import '../shared/archetypes/workflow_master_detail/workflow_master_detail_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/refresh/lifecycle_refresh_scope.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import 'human_resources_area_chrome.dart';
import 'human_resources_attendance_incidents_page.dart';
import 'human_resources_attendance_page.dart';
import 'human_resources_dashboard_page.dart';
import 'human_resources_loans.dart';
import 'human_resources_nomina_page.dart';
import 'human_resources_permissions_page.dart';
import 'human_resources_personnel_page.dart';
import 'human_resources_prenomina_page.dart';
import 'human_resources_terminations_page.dart';
import 'human_resources_theme.dart';
import 'human_resources_vacations_page.dart';
import 'loans/loan_repository.dart';

part 'loans/loan_workspace.dart';
part 'loans/loan_forms.dart';
part 'loans/loan_test_support.dart';

/// Workflow master-detail: loan list, selected account and immutable payments.
/// Uses the shared workflow shell and existing RH chrome / semantic tokens.
class HumanResourcesLoansPage extends StatefulWidget {
  final bool instantOpen;
  const HumanResourcesLoansPage({super.key, this.instantOpen = false});
  @override
  State<HumanResourcesLoansPage> createState() =>
      _HumanResourcesLoansPageState();
}

class _HumanResourcesLoansPageState extends State<HumanResourcesLoansPage> {
  late final _repository = HrLoanRepository(Supabase.instance.client);
  HrLoanFundState? _fund;
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true,
      _menuOpen = false,
      _canReturnToDirection = false,
      _editing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_editing) return;
    try {
      final profile = await AuthAccess.resolveCurrentProfile();
      if (!AuthAccess.hasHumanResourcesAccess(profile)) {
        throw StateError('Tu perfil no tiene acceso a Recursos Humanos.');
      }
      final results = await Future.wait([
        _repository.load(),
        _repository.employees(),
      ]);
      if (!mounted) return;
      setState(() {
        _fund = results[0] as HrLoanFundState;
        _employees = results[1] as List<Map<String, dynamic>>;
        _canReturnToDirection = AuthAccess.canAccessGeneralDashboard(profile);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _loanError(e);
        });
      }
    }
  }

  Future<void> _create() async {
    if (_fund == null || _editing || _error != null) return;
    _editing = true;
    final id = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AreaThemeScope(
        tokens: humanResourcesAreaTokens,
        child: _HrLoanCreateDialog(
          employees: _employees,
          availableCents: _fund!.availableCents,
          onSave: _repository.create,
        ),
      ),
    );
    _editing = false;
    if (!mounted) return;
    await _load();
    if (id != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Préstamo registrado y descontado del fondo.'),
        ),
      );
    }
  }

  Future<void> _cashPayment(HrLoan loan) async {
    if (_fund == null || _editing || _error != null) return;
    _editing = true;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AreaThemeScope(
        tokens: humanResourcesAreaTokens,
        child: _HrLoanCashDialog(
          loan: loan,
          balanceCents: _fund!.balanceCents(loan),
          onSave: _repository.cashPayment,
        ),
      ),
    );
    _editing = false;
    if (!mounted) return;
    await _load();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abono registrado. El importe regresó al fondo.'),
        ),
      );
    }
  }

  Future<void> _navigate(Widget page) async {
    if (_editing) return;
    await Navigator.of(context).pushReplacement(appPageRoute(page: page));
  }

  Future<void> _changeChannel(HrLoan loan) async {
    if (_editing || _error != null) return;
    _editing = true;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AreaThemeScope(
        tokens: humanResourcesAreaTokens,
        child: _HrLoanChannelDialog(
          loan: loan,
          onSave: _repository.setPayrollChannel,
        ),
      ),
    );
    _editing = false;
    if (!mounted) return;
    await _load();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Forma de cobro guardada. Actualiza la prenómina antes de cerrar.',
          ),
        ),
      );
    }
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
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recursos Humanos', style: _loanText(22, strong: true)),
                Text('Préstamos', style: _loanText(14, muted: true)),
              ],
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
                      'No se pudo actualizar el fondo: $_error',
                      style: _loanText(14),
                    ),
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _fund == null
                      ? Center(
                          child: Text(
                            'El fondo no está disponible.',
                            style: _loanText(18),
                          ),
                        )
                      : HrLoansWorkspace(
                          fund: _fund!,
                          onCreate: _error == null ? _create : null,
                          onCashPayment: _error == null ? _cashPayment : null,
                          onChangeChannel: _error == null
                              ? _changeChannel
                              : null,
                        ),
                ),
              ],
            ),
            HumanResourcesAreaNavigationOverlay(
              menuOpen: _menuOpen,
              onDismiss: () => setState(() => _menuOpen = false),
              canReturnToDirection: _canReturnToDirection,
              sections: buildHumanResourcesAreaSections(
                activeScreen: HumanResourcesAreaScreen.loans,
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
                openLoans: () async {},
              ),
              accessItems: buildHumanResourcesAccessItems(
                activeScreen: HumanResourcesAreaScreen.loans,
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

TextStyle _loanText(double size, {bool strong = false, bool muted = false}) =>
    TextStyle(
      color: muted
          ? humanResourcesAreaTokens.badgeText
          : humanResourcesAreaTokens.onGlass,
      fontSize: size,
      fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
    );
String _loanMoney(int cents) => formatMoney(cents / 100);
String _loanError(Object e) => e is PostgrestException
    ? e.message
    : 'No fue posible completar la operación. Intenta de nuevo.';
String _loanRequestId() {
  final random = math.Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
