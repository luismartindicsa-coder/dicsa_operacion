import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shared/utils/file_download_save.dart';
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
import 'human_resources_vacancies_page.dart';
import 'human_resources_attendance_incidents_page.dart';
import 'human_resources_attendance_page.dart';
import 'human_resources_dashboard_page.dart';
import 'human_resources_loans_page.dart';
import 'human_resources_nomina_page.dart';
import 'human_resources_permissions_page.dart';
import 'human_resources_personnel_page.dart';
import 'human_resources_prenomina_page.dart';
import 'human_resources_terminations_page.dart';
import 'human_resources_theme.dart';
import 'human_resources_vacations_page.dart';
import 'documentation/hr_document.dart';
import 'documentation/hr_document_templates.dart';
import 'documentation/hr_document_repository.dart';
import 'documentation/hr_document_pdf.dart';

part 'documentation/hr_document_workspace.dart';
part 'documentation/hr_document_library.dart';
part 'documentation/hr_document_editor.dart';

/// Workflow master-detail, derived from Mantenimiento and RH Préstamos.
/// Categories are subpages of the same RH shell; edits use auxiliary dialogs.
class HumanResourcesDocumentationPage extends StatefulWidget {
  final bool instantOpen;
  const HumanResourcesDocumentationPage({super.key, this.instantOpen = false});
  @override
  State<HumanResourcesDocumentationPage> createState() =>
      _HumanResourcesDocumentationPageState();
}

class _HumanResourcesDocumentationPageState
    extends State<HumanResourcesDocumentationPage> {
  late final _repository = HrDocumentRepository(Supabase.instance.client);
  List<HrDocument> _records = [];
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true,
      _refreshing = false,
      _editing = false,
      _menuOpen = false,
      _canReturnToDirection = false;
  String? _error, _employeeError;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_editing || _refreshing) return;
    _refreshing = true;
    try {
      final profile = await AuthAccess.resolveCurrentProfile();
      if (!AuthAccess.hasHumanResourcesAccess(profile)) {
        if (mounted) setState(() => _records = []);
        throw StateError('Tu perfil no tiene acceso a Documentación RH.');
      }
      final records = await _repository.load();
      List<Map<String, dynamic>> employees = _employees;
      String? employeeError;
      try {
        employees = await _repository.employees();
      } catch (_) {
        employeeError =
            'El catálogo de personal no está disponible. Puedes capturar los datos manualmente.';
      }
      if (mounted) {
        setState(() {
          _records = records;
          _employees = employees;
          _employeeError = employeeError;
          _error = null;
          _canReturnToDirection = AuthAccess.canAccessGeneralDashboard(profile);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _hrDocError(e));
    } finally {
      _refreshing = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(HrDocument document) async {
    if (_editing || _error != null) return;
    _editing = true;
    try {
      await showDialog<HrDocument>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AreaThemeScope(
          tokens: humanResourcesAreaTokens,
          child: HrDocumentEditor(
            document: document,
            employees: _employees,
            employeeError: _employeeError,
            onSave: _repository.save,
            onPdf: _exportPdf,
          ),
        ),
      );
    } finally {
      _editing = false;
    }
    if (mounted) await _load();
  }

  Future<void> _exportPdf(HrDocument document) async {
    final bytes = await buildHrDocumentPdf(document);
    final path = await saveBytesAs(
      bytes: bytes,
      suggestedFileName: '${document.folio}.pdf',
      throwOnPickerError: true,
      dialogTitle: 'Guardar PDF para impresión',
    );
    if (path != null && mounted) {
      _message('PDF guardado. Puedes abrirlo para imprimir.');
      await launchUrl(Uri.file(path));
    }
  }

  Future<void> _openFile(HrDocument document) async {
    try {
      if (!await launchUrl(
        await _repository.fileUrl(document),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('No se pudo abrir el archivo. Usa Descargar archivo.');
      }
    } catch (e) {
      _message(_hrDocError(e));
    }
  }

  Future<void> _download(HrDocument document) async {
    try {
      if (document.kind == 'generated') {
        await _exportPdf(document);
        return;
      }
      final bytes = await _repository.download(document);
      final path = await saveBytesAs(
        bytes: bytes,
        suggestedFileName: document.file!['name'] as String,
        throwOnPickerError: true,
      );
      if (path != null) _message('Archivo guardado.');
    } catch (e) {
      _message(_hrDocError(e));
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _navigate(Widget page) async {
    if (!_editing) {
      await Navigator.of(context).pushReplacement(appPageRoute(page: page));
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
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recursos Humanos', style: _hrDocText(22, strong: true)),
                Text('Documentación RH', style: _hrDocText(14, muted: true)),
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
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'No se pudo actualizar Documentación RH: $_error',
                      style: _hrDocText(14),
                    ),
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : HrDocumentWorkspace(
                          records: _records,
                          onEdit: _error == null ? _edit : null,
                          onDownload: _download,
                          onOpenFile: _openFile,
                        ),
                ),
              ],
            ),
            HumanResourcesAreaNavigationOverlay(
              menuOpen: _menuOpen,
              onDismiss: () => setState(() => _menuOpen = false),
              canReturnToDirection: _canReturnToDirection,
              sections: buildHumanResourcesAreaSections(
                openVacancies: () => _navigate(
                  const HumanResourcesVacanciesPage(instantOpen: true),
                ),
                activeScreen: HumanResourcesAreaScreen.documentation,
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
                openDocumentation: () async {},
              ),
              accessItems: buildHumanResourcesAccessItems(
                activeScreen: HumanResourcesAreaScreen.documentation,
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

TextStyle _hrDocText(double size, {bool strong = false, bool muted = false}) =>
    TextStyle(
      fontSize: size,
      fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
      color: muted
          ? humanResourcesAreaTokens.badgeText
          : humanResourcesAreaTokens.onGlass,
    );

String _hrDocError(Object error) => switch (error) {
  PostgrestException e => e.message,
  StorageException e => e.message,
  FormatException e => e.message,
  StateError e => e.message,
  _ =>
    'No fue posible completar la operación. Revisa la conexión e intenta de nuevo.',
};
