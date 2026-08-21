import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xml/xml.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/archetypes/operacion_hibrida_tabs/operacion_hibrida_tabs.dart';
import '../shared/archetypes/auxiliary_surfaces/confirmation_dialog.dart';
import '../shared/page_routes.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'human_resources_attendance_page.dart';
import 'human_resources_area_chrome.dart';
import 'human_resources_dashboard_page.dart';
import 'human_resources_employee_status.dart';
import 'human_resources_nomina_page.dart';
import 'human_resources_permissions_page.dart';
import 'human_resources_personnel_page.dart';
import 'human_resources_prenomina_page.dart';
import 'human_resources_theme.dart';
import 'human_resources_vacations_page.dart';

class HumanResourcesAttendanceIncidentsPage extends StatefulWidget {
  final bool instantOpen;

  const HumanResourcesAttendanceIncidentsPage({
    super.key,
    this.instantOpen = false,
  });

  @override
  State<HumanResourcesAttendanceIncidentsPage> createState() =>
      _HumanResourcesAttendanceIncidentsPageState();
}

class _HumanResourcesAttendanceIncidentsPageState
    extends State<HumanResourcesAttendanceIncidentsPage> {
  static const String _kProfilesTable = 'hr_employee_profiles';
  static const String _kImportLotsTable = 'hr_attendance_import_lots';
  static const String _kAdjustmentsTable = 'hr_attendance_manual_adjustments';

  late final OperacionHibridaTabsController _tabs =
      OperacionHibridaTabsController(initialTabId: 'importaciones');

  bool _menuOpen = false;
  bool _canReturnToDirection = false;
  bool _loadingSummary = true;
  int _employeeCount = 0;
  List<_HrAttendanceEmployeeMaster> _employees =
      const <_HrAttendanceEmployeeMaster>[];
  bool _importingNgteco = false;
  bool _importingContpaq = false;
  final List<_HrAttendanceImportLot> _importLots = <_HrAttendanceImportLot>[];
  final List<_HrAttendanceManualAdjustment> _manualAdjustments =
      <_HrAttendanceManualAdjustment>[];

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadSummary());
    unawaited(_loadSavedImportLots());
    unawaited(_loadSavedAdjustments());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(
      () =>
          _canReturnToDirection = AuthAccess.canAccessGeneralDashboard(profile),
    );
  }

  Future<void> _loadSummary() async {
    try {
      final result = await fetchAllSupabaseRows(
        (from, to) => Supabase.instance.client
            .from(_kProfilesTable)
            .select(
              'id,nombre,empresa,horario,dias_labora,labor_schedules,fecha_ingreso,salario',
            )
            .neq('employment_status', kHrEmployeeStatusTerminated)
            .order('id')
            .range(from, to),
      );
      if (!mounted) return;
      final rows =
          result
              .map((raw) => Map<String, dynamic>.from(raw))
              .map(
                (row) => _HrAttendanceEmployeeMaster(
                  employeeId: (row['id'] ?? '').toString(),
                  displayName: (row['nombre'] ?? '').toString(),
                  empresa: (row['empresa'] ?? '').toString(),
                  horario: (row['horario'] ?? '').toString(),
                  diasLabora: _parseAttendanceWeekdays(row['dias_labora']),
                  workSchedules: _parseAttendanceWorkSchedules(
                    row['labor_schedules'],
                    fallbackHorario: (row['horario'] ?? '').toString(),
                    fallbackDiasLabora: _parseAttendanceWeekdays(
                      row['dias_labora'],
                    ),
                  ),
                  fechaIngreso: (row['fecha_ingreso'] ?? '').toString(),
                  salario: (row['salario'] ?? '').toString(),
                ),
              )
              .where((row) => row.employeeId.trim().isNotEmpty)
              .toList(growable: false)
            ..sort((a, b) {
              final aInt = int.tryParse(a.employeeId);
              final bInt = int.tryParse(b.employeeId);
              if (aInt != null && bInt != null) return aInt.compareTo(bInt);
              return a.employeeId.compareTo(b.employeeId);
            });
      setState(() {
        _employees = rows;
        _employeeCount = rows.length;
        _loadingSummary = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSummary = false);
    }
  }

  Future<void> _loadSavedImportLots() async {
    try {
      final result = await fetchAllSupabaseRows(
        (from, to) => Supabase.instance.client
            .from(_kImportLotsTable)
            .select()
            .order('imported_at', ascending: false)
            .range(from, to),
      );
      if (!mounted) return;
      final lots = result
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(_HrAttendanceImportLot.fromRow)
          .toList(growable: false);
      setState(() {
        _importLots
          ..clear()
          ..addAll(lots);
      });
    } catch (_) {
      // Keep the screen usable even if the persistence table does not exist yet.
    }
  }

  Future<void> _loadSavedAdjustments() async {
    try {
      final result = await fetchAllSupabaseRows(
        (from, to) => Supabase.instance.client
            .from(_kAdjustmentsTable)
            .select()
            .order('source_date')
            .order('created_at')
            .range(from, to),
      );
      if (!mounted) return;
      final rows = result
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(_HrAttendanceManualAdjustment.fromRow)
          .toList(growable: false);
      setState(() {
        _manualAdjustments
          ..clear()
          ..addAll(rows);
      });
    } catch (_) {
      // Keep the screen usable even if the persistence table does not exist yet.
    }
  }

  Future<void> _logout() async => signOutAndRouteToLogin(context);

  Future<void> _pickImportFile(_HrAttendanceImportSource source) async {
    final importing = source == _HrAttendanceImportSource.ngteco
        ? _importingNgteco
        : _importingContpaq;
    if (importing) return;
    setState(() {
      if (source == _HrAttendanceImportSource.ngteco) {
        _importingNgteco = true;
      } else {
        _importingContpaq = true;
      }
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        lockParentWindow: true,
        type: FileType.custom,
        allowedExtensions: source == _HrAttendanceImportSource.ngteco
            ? const ['csv']
            : const ['xlsx'],
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) return;
      final lot = source == _HrAttendanceImportSource.ngteco
          ? _parseNgtecoImportLot(file.name, bytes)
          : _parseContpaqImportLot(file.name, bytes);
      await _persistImportLot(lot);
      if (!mounted) return;
      setState(() {
        _importLots.insert(0, lot);
        _tabs.activateTab('importaciones');
      });
      _showSnack(
        'Importación ${lot.source.label}: ${lot.validRows} válidas, ${lot.rejectedRows} rechazadas.',
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack('No se pudo importar el archivo. $error');
    } finally {
      if (mounted) {
        setState(() {
          if (source == _HrAttendanceImportSource.ngteco) {
            _importingNgteco = false;
          } else {
            _importingContpaq = false;
          }
        });
      }
    }
  }

  Future<void> _persistImportLot(_HrAttendanceImportLot lot) async {
    await Supabase.instance.client
        .from(_kImportLotsTable)
        .upsert(lot.toRow(), onConflict: 'id');
  }

  Future<void> _deleteImportLot(_HrAttendanceImportLot lot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar importación'),
          content: Text(
            'Se eliminará el lote ${lot.fileName} de ${lot.source.label}. Esta acción no afecta Personal, solo el staging importado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client
          .from(_kImportLotsTable)
          .delete()
          .eq('id', lot.id);
      if (!mounted) return;
      setState(() {
        _importLots.removeWhere((item) => item.id == lot.id);
      });
      _showSnack('Importación eliminada.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('No se pudo eliminar la importación. $error');
    }
  }

  Future<void> _createManualAdjustment(
    _HrAttendanceManualAdjustment adjustment,
  ) async {
    await Supabase.instance.client
        .from(_kAdjustmentsTable)
        .upsert(adjustment.toRow(), onConflict: 'id');
    if (!mounted) return;
    setState(() {
      _manualAdjustments.insert(0, adjustment);
      _tabs.activateTab('conciliaciones');
    });
  }

  Future<void> _deleteManualAdjustment(
    _HrAttendanceManualAdjustment adjustment,
  ) async {
    final confirmed = await showContractConfirmationDialog(
      context,
      title: 'Eliminar corrección',
      content:
          'Se eliminará la corrección de ${adjustment.employeeName} del ${adjustment.sourceDate}.',
      confirmText: 'Eliminar',
      tokens: humanResourcesAreaTokens,
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client
          .from(_kAdjustmentsTable)
          .delete()
          .eq('id', adjustment.id);
      if (!mounted) return;
      setState(() {
        _manualAdjustments.removeWhere((row) => row.id == adjustment.id);
      });
      _showSnack('Corrección eliminada.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('No se pudo eliminar la corrección. $error');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openPersonnel() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesPersonnelPage(instantOpen: true)),
    );
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openAttendance() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesAttendancePage(instantOpen: true)),
    );
  }

  Future<void> _openVacations() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesVacationsPage(instantOpen: true)),
    );
  }

  Future<void> _openPermissions() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const HumanResourcesPermissionsPage(instantOpen: true),
      ),
    );
  }

  Future<void> _openPrenomina() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesPrenominaPage(instantOpen: true)),
    );
  }

  Future<void> _openNomina() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesNominaPage(instantOpen: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AreaThemeScope(
      tokens: humanResourcesAreaTokens,
      child: AppShell(
        background: const HumanResourcesAreaBackground(),
        wrapBodyInGlass: false,
        animateHeaderSlots: false,
        animateBody: !widget.instantOpen,
        headerBodySpacing: 8,
        padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
        leadingBuilder: (_, _) => HumanResourcesAreaHeaderButton(
          label: _menuOpen ? 'Cerrar panel' : 'Navegación',
          icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
          onTapSync: () => setState(() => _menuOpen = !_menuOpen),
        ),
        centerBuilder: (_, _) => const _HrAttendanceBrand(),
        trailingBuilder: (_, _) => HumanResourcesAreaHeaderButton(
          label: 'Cerrar sesión',
          icon: Icons.logout_rounded,
          onTap: _logout,
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1540),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(56, 4, 8, 0),
                  child: _HrAttendanceWorkspace(
                    tabs: _tabs,
                    loadingSummary: _loadingSummary,
                    employeeCount: _employeeCount,
                    employees: _employees,
                    importLots: _importLots,
                    manualAdjustments: _manualAdjustments,
                    onImportNgteco: () =>
                        _pickImportFile(_HrAttendanceImportSource.ngteco),
                    onImportContpaq: () =>
                        _pickImportFile(_HrAttendanceImportSource.contpaq),
                    importingNgteco: _importingNgteco,
                    importingContpaq: _importingContpaq,
                    onDeleteLot: _deleteImportLot,
                    onCreateManualAdjustment: _createManualAdjustment,
                    onDeleteManualAdjustment: _deleteManualAdjustment,
                  ),
                ),
              ),
            ),
            HumanResourcesAreaNavigationOverlay(
              menuOpen: _menuOpen,
              onDismiss: () => setState(() => _menuOpen = false),
              canReturnToDirection: _canReturnToDirection,
              sections: buildHumanResourcesAreaSections(
                activeScreen: HumanResourcesAreaScreen.importConciliation,
                openPersonnel: _openPersonnel,
                openAttendance: _openAttendance,
                openImportConciliation: () async {},
                openVacations: _openVacations,
                openPermissions: _openPermissions,
                openPrenomina: _openPrenomina,
                openNomina: _openNomina,
              ),
              accessItems: buildHumanResourcesAccessItems(
                activeScreen: HumanResourcesAreaScreen.importConciliation,
                openDashboard: _openDashboard,
                canReturnToDirection: _canReturnToDirection,
                openDirectionDashboard: _openDirectionDashboard,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrAttendanceWorkspace extends StatelessWidget {
  final OperacionHibridaTabsController tabs;
  final bool loadingSummary;
  final int employeeCount;
  final List<_HrAttendanceEmployeeMaster> employees;
  final List<_HrAttendanceImportLot> importLots;
  final List<_HrAttendanceManualAdjustment> manualAdjustments;
  final Future<void> Function() onImportNgteco;
  final Future<void> Function() onImportContpaq;
  final bool importingNgteco;
  final bool importingContpaq;
  final Future<void> Function(_HrAttendanceImportLot lot) onDeleteLot;
  final Future<void> Function(_HrAttendanceManualAdjustment adjustment)
  onCreateManualAdjustment;
  final Future<void> Function(_HrAttendanceManualAdjustment adjustment)
  onDeleteManualAdjustment;

  const _HrAttendanceWorkspace({
    required this.tabs,
    required this.loadingSummary,
    required this.employeeCount,
    required this.employees,
    required this.importLots,
    required this.manualAdjustments,
    required this.onImportNgteco,
    required this.onImportContpaq,
    required this.importingNgteco,
    required this.importingContpaq,
    required this.onDeleteLot,
    required this.onCreateManualAdjustment,
    required this.onDeleteManualAdjustment,
  });

  @override
  Widget build(BuildContext context) {
    final latestNgteco = _latestLotBySource(
      importLots,
      _HrAttendanceImportSource.ngteco,
    );
    final latestContpaq = _latestLotBySource(
      importLots,
      _HrAttendanceImportSource.contpaq,
    );
    final activePeriodLabel = _resolveActiveAttendancePeriodLabel(
      ngtecoLot: latestNgteco,
      contpaqLot: latestContpaq,
    );
    final attendanceRows = _buildAttendanceRows(
      employees: employees,
      ngtecoLot: latestNgteco,
      contpaqLot: latestContpaq,
    );
    final currentAdjustments = manualAdjustments
        .where((row) => row.periodLabel == activePeriodLabel)
        .toList(growable: false);
    final tardinessRows = _buildTardinessRows(
      employees: employees,
      ngtecoLot: latestNgteco,
      adjustments: currentAdjustments,
    );
    final absenceRows = _buildAbsenceRows(
      employees: employees,
      ngtecoLot: latestNgteco,
      contpaqLot: latestContpaq,
      adjustments: currentAdjustments,
    );
    final tabsSpec = const [
      ('importaciones', 'Importaciones'),
      ('conciliaciones', 'Conciliaciones'),
    ];

    return AnimatedBuilder(
      animation: tabs,
      builder: (context, _) {
        return OperacionHibridaTabsShell(
          tabs: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (id, label) in tabsSpec)
                _HrAttendanceTabChip(
                  label: label,
                  selected: tabs.activeTabId == id,
                  onTap: () => tabs.activateTab(id),
                ),
            ],
          ),
          body: OperacionTabViewHost(
            activeTabId: tabs.activeTabId,
            tabViews: {
              'importaciones': _HrAttendancePanel(
                title: 'Importaciones',
                subtitle:
                    'Los archivos se cargan en staging. Ningún lote modifica la prenómina hasta ser conciliado.',
                child: _HrAttendanceImportationsBody(
                  lots: importLots,
                  onImportNgteco: onImportNgteco,
                  onImportContpaq: onImportContpaq,
                  importingNgteco: importingNgteco,
                  importingContpaq: importingContpaq,
                  onDeleteLot: onDeleteLot,
                ),
              ),
              'conciliaciones': _HrAttendancePanel(
                title: '',
                subtitle: '',
                child: _HrAttendanceReconciliationBody(
                  attendanceRows: attendanceRows,
                  tardinessRows: tardinessRows,
                  absenceRows: absenceRows,
                  ngtecoLot: latestNgteco,
                  contpaqLot: latestContpaq,
                ),
              ),
            },
          ),
        );
      },
    );
  }
}

class _HrAttendanceTabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HrAttendanceTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE7D4FF) : const Color(0x8B25163A),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFF9F6BFF)
                : Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: selected ? const Color(0xFF24103D) : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _HrAttendancePanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _HrAttendancePanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final hasHeader = title.trim().isNotEmpty || subtitle.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xCB1D112F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasHeader) ...[
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.68),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _HrAttendanceReconciliationBody extends StatefulWidget {
  final List<_HrAttendanceStageRow> attendanceRows;
  final List<_HrAttendanceTardinessRow> tardinessRows;
  final List<_HrAttendanceAbsenceRow> absenceRows;
  final _HrAttendanceImportLot? ngtecoLot;
  final _HrAttendanceImportLot? contpaqLot;

  const _HrAttendanceReconciliationBody({
    required this.attendanceRows,
    required this.tardinessRows,
    required this.absenceRows,
    required this.ngtecoLot,
    required this.contpaqLot,
  });

  @override
  State<_HrAttendanceReconciliationBody> createState() =>
      _HrAttendanceReconciliationBodyState();
}

class _HrAttendanceReconciliationBodyState
    extends State<_HrAttendanceReconciliationBody> {
  String _activeSection = 'cruce';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final attendanceRows = widget.attendanceRows;
    final tardinessRows = widget.tardinessRows
        .where(_isRelevantTardinessRow)
        .toList(growable: false);
    final absenceRows = widget.absenceRows.toList(growable: false);
    final filteredAttendanceRows = attendanceRows
        .where(
          (row) => _matchesAttendanceSearch(
            query: _searchQuery,
            employeeId: row.employeeId,
            displayName: row.displayName,
            empresa: row.empresa,
          ),
        )
        .toList(growable: false);
    final filteredTardinessRows = tardinessRows
        .where(
          (row) => _matchesAttendanceSearch(
            query: _searchQuery,
            employeeId: row.employeeId,
            displayName: row.displayName,
            empresa: row.empresa,
          ),
        )
        .toList(growable: false);
    final filteredAbsenceRows = absenceRows
        .where(
          (row) => _matchesAttendanceSearch(
            query: _searchQuery,
            employeeId: row.employeeId,
            displayName: row.displayName,
            empresa: row.empresa,
          ),
        )
        .toList(growable: false);

    Widget activeBody;
    switch (_activeSection) {
      case 'retardos':
        activeBody = _HrAttendanceTardinessBody(rows: filteredTardinessRows);
        break;
      case 'faltas':
        activeBody = _HrAttendanceAbsenceBody(rows: filteredAbsenceRows);
        break;
      case 'cruce':
      default:
        activeBody = _HrAttendanceStagingBody(rows: filteredAttendanceRows);
        break;
    }

    final crossedCount = attendanceRows
        .where(
          (row) =>
              !row.requiresManualCapture &&
              !row.missingScheduleBase &&
              !row.missingWorkdaysBase,
        )
        .length;
    final manualCount = attendanceRows
        .where((row) => row.requiresManualCapture)
        .length;
    final noPunchCount = attendanceRows
        .where((row) => !row.presentInNgteco)
        .length;
    final likelyAbsenceCount = absenceRows
        .where((row) => row.statusLabel == 'Falta probable')
        .length;
    final periodLabel = _resolveActiveAttendancePeriodLabel(
      ngtecoLot: widget.ngtecoLot,
      contpaqLot: widget.contpaqLot,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HrAttendanceContextCard(
          title: 'Conciliaciones',
          periodLabel: periodLabel,
          ngtecoLot: widget.ngtecoLot,
          contpaqLot: widget.contpaqLot,
        ),
        const SizedBox(height: 12),
        _HrAttendanceSummaryCard(
          items: [
            _HrSummaryMetric(
              label: 'Colaboradores',
              value: attendanceRows.length.toString(),
            ),
            _HrSummaryMetric(label: 'Cruzados', value: crossedCount.toString()),
            _HrSummaryMetric(label: 'Manuales', value: manualCount.toString()),
            _HrSummaryMetric(
              label: 'Sin fichaje',
              value: noPunchCount.toString(),
            ),
            _HrSummaryMetric(
              label: 'Retardos',
              value: tardinessRows.length.toString(),
            ),
            _HrSummaryMetric(
              label: 'Faltas probables',
              value: likelyAbsenceCount.toString(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HrAttendanceTabChip(
              label: 'Cruce ${attendanceRows.length}',
              selected: _activeSection == 'cruce',
              onTap: () => setState(() => _activeSection = 'cruce'),
            ),
            _HrAttendanceTabChip(
              label: 'Retardos ${tardinessRows.length}',
              selected: _activeSection == 'retardos',
              onTap: () => setState(() => _activeSection = 'retardos'),
            ),
            _HrAttendanceTabChip(
              label: 'Faltas y ausencias ${absenceRows.length}',
              selected: _activeSection == 'faltas',
              onTap: () => setState(() => _activeSection = 'faltas'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _HrAttendanceToolbar(
          hintText: 'Buscar colaborador, ID o empresa...',
          value: _searchQuery,
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        const SizedBox(height: 12),
        Expanded(child: activeBody),
      ],
    );
  }
}

class _HrAttendanceImportationsBody extends StatefulWidget {
  final List<_HrAttendanceImportLot> lots;
  final Future<void> Function() onImportNgteco;
  final Future<void> Function() onImportContpaq;
  final bool importingNgteco;
  final bool importingContpaq;
  final Future<void> Function(_HrAttendanceImportLot lot) onDeleteLot;

  const _HrAttendanceImportationsBody({
    required this.lots,
    required this.onImportNgteco,
    required this.onImportContpaq,
    required this.importingNgteco,
    required this.importingContpaq,
    required this.onDeleteLot,
  });

  @override
  State<_HrAttendanceImportationsBody> createState() =>
      _HrAttendanceImportationsBodyState();
}

class _HrAttendanceImportationsBodyState
    extends State<_HrAttendanceImportationsBody> {
  String _selectedLotId = '';

  @override
  Widget build(BuildContext context) {
    final sortedLots = [...widget.lots]
      ..sort((a, b) => b.importedAt.compareTo(a.importedAt));
    final selectedLot = sortedLots.any((lot) => lot.id == _selectedLotId)
        ? sortedLots.firstWhere((lot) => lot.id == _selectedLotId)
        : sortedLots.isNotEmpty
        ? sortedLots.first
        : null;
    final previewEntries =
        selectedLot?.entries ?? const <_HrAttendanceImportedEntry>[];

    return ListView(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final useRow = constraints.maxWidth >= 920;
            final ngtecoCard = _HrImportSourceCard(
              title: 'NGTeco',
              body:
                  'CSV de reloj checador. Requiere employee_id y fecha/hora de fichaje.',
              buttonLabel: widget.importingNgteco
                  ? 'Importando...'
                  : 'Importar NGTeco',
              icon: Icons.fingerprint_rounded,
              onTap: widget.importingNgteco ? null : widget.onImportNgteco,
            );
            final contpaqCard = _HrImportSourceCard(
              title: 'CONTPAQ',
              body:
                  'XLSX de lista de raya. Requiere Codigo, Empleado, Sueldo y Neto.',
              buttonLabel: widget.importingContpaq
                  ? 'Importando...'
                  : 'Importar CONTPAQ',
              icon: Icons.payments_outlined,
              onTap: widget.importingContpaq ? null : widget.onImportContpaq,
            );
            if (!useRow) {
              return Column(
                children: [ngtecoCard, const SizedBox(height: 12), contpaqCard],
              );
            }
            return Row(
              children: [
                Expanded(child: ngtecoCard),
                const SizedBox(width: 12),
                Expanded(child: contpaqCard),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Sube NGTeco y CONTPAQ a staging. Ningún lote pega directo a prenómina.',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            height: 1.4,
            color: Colors.white.withValues(alpha: 0.70),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              'Lotes importados',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Text(
              '${sortedLots.length} lote(s)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (sortedLots.isEmpty)
          const _HrAttendanceEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Sin lotes importados',
            body:
                'Sube un CSV de NGTeco o un XLSX de CONTPAQ para registrar el lote, contar filas válidas/rechazadas y abrir el staging inicial.',
          )
        else
          Column(
            children: [
              for (var i = 0; i < sortedLots.length; i++) ...[
                _HrImportLotCard(
                  lot: sortedLots[i],
                  onSelect: () =>
                      setState(() => _selectedLotId = sortedLots[i].id),
                  onDelete: () async {
                    if (_selectedLotId == sortedLots[i].id) {
                      setState(() => _selectedLotId = '');
                    }
                    await widget.onDeleteLot(sortedLots[i]);
                  },
                ),
                if (i != sortedLots.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        const SizedBox(height: 12),
        if (selectedLot == null)
          const _HrAttendanceEmptyState(
            icon: Icons.preview_outlined,
            title: 'Selecciona un lote',
            body:
                'Elige un lote importado para revisar qué filas y montos está leyendo la app.',
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vista previa',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${selectedLot.source.label} · ${selectedLot.fileName}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _describeImportPeriod(selectedLot),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 12),
              _HrImportPreviewPanel(lot: selectedLot, entries: previewEntries),
            ],
          ),
      ],
    );
  }
}

class _HrAttendanceStagingBody extends StatelessWidget {
  final List<_HrAttendanceStageRow> rows;

  const _HrAttendanceStagingBody({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _HrAttendanceEmptyState(
        icon: Icons.fact_check_outlined,
        title: 'Sin padrón RH cargado',
        body:
            'Primero se necesita el padrón maestro de Personal para poder construir el staging semanal por employee_id.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x8B140B25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Column(
              children: [
                const _HrAttendanceStageHeader(),
                Expanded(
                  child: ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) =>
                        _HrAttendanceStageRowTile(row: rows[index]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HrAttendanceTardinessBody extends StatelessWidget {
  final List<_HrAttendanceTardinessRow> rows;

  const _HrAttendanceTardinessBody({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _HrAttendanceEmptyState(
        icon: Icons.timer_outlined,
        title: 'Sin base para retardos',
        body:
            'Carga NGTeco y completa horario/días labora en Personal para calcular minutos tarde sobre la semana activa.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x8B140B25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Column(
              children: [
                const _HrAttendanceTardinessHeader(),
                Expanded(
                  child: ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) =>
                        _HrAttendanceTardinessRowTile(row: rows[index]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HrAttendanceAbsenceBody extends StatelessWidget {
  final List<_HrAttendanceAbsenceRow> rows;

  const _HrAttendanceAbsenceBody({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _HrAttendanceEmptyState(
        icon: Icons.event_busy_outlined,
        title: 'Sin staging de ausencias',
        body:
            'Aquí se consolidarán faltas, ausencias parciales y señales administrativas de CONTPAQ antes del envío a prenómina.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x8B140B25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Column(
              children: [
                const _HrAttendanceAbsenceHeader(),
                Expanded(
                  child: ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) =>
                        _HrAttendanceAbsenceRowTile(row: rows[index]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HrImportSourceCard extends StatelessWidget {
  final String title;
  final String body;
  final String buttonLabel;
  final IconData icon;
  final Future<void> Function()? onTap;

  const _HrImportSourceCard({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xE625163A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x44B084FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A2558),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFFCFAEFF)),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.70),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: contractPrimaryButtonStyle(context),
            onPressed: onTap == null ? null : () async => onTap!(),
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _HrImportLotCard extends StatelessWidget {
  final _HrAttendanceImportLot lot;
  final VoidCallback onSelect;
  final Future<void> Function() onDelete;

  const _HrImportLotCard({
    required this.lot,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xE625163A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x44B084FF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lot.source.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFCFAEFF),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lot.fileName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _describeImportPeriod(lot),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.68),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Importado ${_fmtHrImportDateTime(lot.importedAt)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${lot.validRows} filas válidas · ${lot.rejectedRows} rechazadas · ${lot.uniqueEmployeeIds.length} IDs detectados',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              if (lot.issues.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final issue in lot.issues.take(4))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x33FFB4B4),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x66FFB4B4)),
                        ),
                        child: Text(
                          issue,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFFE8E8),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  style: contractSecondaryButtonStyle(context),
                  onPressed: () async => onDelete(),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Borrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HrImportPreviewHeader extends StatelessWidget {
  final _HrAttendanceImportSource source;

  const _HrImportPreviewHeader({required this.source});

  @override
  Widget build(BuildContext context) {
    final isNgteco = source == _HrAttendanceImportSource.ngteco;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF3A2558),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 78,
            child: Text(
              'ID',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const Expanded(
            flex: 3,
            child: Text(
              'Empleado',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          if (isNgteco)
            const Expanded(
              flex: 2,
              child: Text(
                'Fecha / hora',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            )
          else ...[
            const SizedBox(
              width: 118,
              child: Text(
                'Sueldo',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const SizedBox(
              width: 118,
              child: Text(
                'Neto',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          const SizedBox(width: 12),
          const SizedBox(
            width: 90,
            child: Text(
              'Estado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrImportPreviewEntryTile extends StatelessWidget {
  final _HrAttendanceImportSource source;
  final _HrAttendanceImportedEntry entry;
  final bool isLast;

  const _HrImportPreviewEntryTile({
    required this.source,
    required this.entry,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isNgteco = source == _HrAttendanceImportSource.ngteco;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              entry.employeeId,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              entry.sourceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.76),
              ),
            ),
          ),
          if (isNgteco)
            Expanded(
              flex: 2,
              child: Text(
                entry.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
            )
          else ...[
            SizedBox(
              width: 118,
              child: Text(
                _fmtHrCurrency(entry.salary),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 118,
              child: Text(
                _fmtHrCurrency(entry.net),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
            ),
          ],
          const SizedBox(width: 12),
          const SizedBox(
            width: 90,
            child: Center(
              child: _HrStagePresencePill(label: 'Válido', positive: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrImportPreviewPanel extends StatelessWidget {
  final _HrAttendanceImportLot lot;
  final List<_HrAttendanceImportedEntry> entries;

  const _HrImportPreviewPanel({required this.lot, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _HrAttendanceEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Sin filas para mostrar',
        body:
            'La búsqueda actual no encontró empleados dentro del lote seleccionado.',
      );
    }

    final previewRows = entries.take(12).toList(growable: false);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0x8B140B25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          _HrImportPreviewHeader(source: lot.source),
          for (var i = 0; i < previewRows.length; i++)
            _HrImportPreviewEntryTile(
              source: lot.source,
              entry: previewRows[i],
              isLast: i == previewRows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _HrAttendanceContextCard extends StatelessWidget {
  final String title;
  final String periodLabel;
  final _HrAttendanceImportLot? ngtecoLot;
  final _HrAttendanceImportLot? contpaqLot;

  const _HrAttendanceContextCard({
    required this.title,
    required this.periodLabel,
    required this.ngtecoLot,
    required this.contpaqLot,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xE625163A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x44B084FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          if (periodLabel.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              periodLabel,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HrLotContextPill(
                label: ngtecoLot == null
                    ? 'NGTeco pendiente'
                    : 'NGTeco · ${_fmtHrImportDateTime(ngtecoLot!.importedAt)}',
              ),
              _HrLotContextPill(
                label: contpaqLot == null
                    ? 'CONTPAQ pendiente'
                    : 'CONTPAQ · ${_fmtHrImportDateTime(contpaqLot!.importedAt)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HrLotContextPill extends StatelessWidget {
  final String label;

  const _HrLotContextPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2558),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _HrSummaryMetric {
  final String label;
  final String value;

  const _HrSummaryMetric({required this.label, required this.value});
}

class _HrAttendanceSummaryCard extends StatelessWidget {
  final List<_HrSummaryMetric> items;

  const _HrAttendanceSummaryCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xE625163A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x44B084FF)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final item in items)
            Container(
              constraints: const BoxConstraints(minWidth: 130),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xFF3A2558),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HrAttendanceToolbar extends StatelessWidget {
  final String hintText;
  final String value;
  final ValueChanged<String> onChanged;

  const _HrAttendanceToolbar({
    required this.hintText,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xA625163A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: TextFormField(
        initialValue: value,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.46),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withValues(alpha: 0.66),
            size: 17,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 28,
            minHeight: 28,
          ),
        ),
      ),
    );
  }
}

class _HrAttendanceStageHeader extends StatelessWidget {
  const _HrAttendanceStageHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF3A2558),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              'ID',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Colaborador',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Empresa',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Jornada',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'NGTeco',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'CONTPAQ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              'Estado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              'Acción',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrAttendanceStageRowTile extends StatelessWidget {
  final _HrAttendanceStageRow row;

  const _HrAttendanceStageRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              row.employeeId,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Ingreso: ${row.fechaIngreso.isEmpty ? 'Pendiente' : row.fechaIngreso}${row.diasLabora.isEmpty ? '' : ' · ${row.diasLabora.join(', ')}'}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.empresa.isEmpty ? 'Pendiente' : row.empresa,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.horario.isEmpty ? 'Pendiente' : row.horario,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _HrStagePresencePill(
                    label: row.presentInNgteco ? 'Con fichaje' : 'Sin fichaje',
                    positive: row.presentInNgteco,
                  ),
                ),
                if (row.presentInNgteco) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${row.ngtecoDaysCount} día(s) · ${row.ngtecoPunchCount} registro(s)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.66),
                    ),
                  ),
                  if (row.ngtecoFirstStamp.isNotEmpty)
                    Text(
                      'Primero ${row.ngtecoFirstStamp}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.56),
                      ),
                    ),
                  if (row.ngtecoLastStamp.isNotEmpty &&
                      row.ngtecoLastStamp != row.ngtecoFirstStamp)
                    Text(
                      'Último ${row.ngtecoLastStamp}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.56),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _HrStagePresencePill(
                    label: row.presentInContpaq ? 'En nómina' : 'Sin nómina',
                    positive: row.presentInContpaq,
                  ),
                ),
                if (row.presentInContpaq) ...[
                  const SizedBox(height: 4),
                  if (row.contpaqSalary.isNotEmpty)
                    Text(
                      'Sueldo ${_fmtHrCurrency(row.contpaqSalary)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.66),
                      ),
                    ),
                  if (row.contpaqNet.isNotEmpty)
                    Text(
                      'Neto ${_fmtHrCurrency(row.contpaqNet)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.56),
                      ),
                    ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: Center(
              child: _HrStagePresencePill(
                label: _hrStageStatusLabel(row),
                positive: _hrStageStatusPositive(row),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Center(
              child: _HrStagePresencePill(
                label: _hrStageNextActionLabel(row),
                positive: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrAttendanceTardinessHeader extends StatelessWidget {
  const _HrAttendanceTardinessHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF3A2558),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              'ID',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Colaborador',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Día',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Jornada',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Fichajes',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Retardo',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              'Estado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              'Acción',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrAttendanceAbsenceHeader extends StatelessWidget {
  const _HrAttendanceAbsenceHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              'ID',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Colaborador',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Día',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Jornada',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'NGTeco',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'CONTPAQ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Clasificación',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              'Acción',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrAttendanceTardinessRowTile extends StatelessWidget {
  final _HrAttendanceTardinessRow row;

  const _HrAttendanceTardinessRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final positive = row.calculable && row.lateMinutes == 0;
    final warning = !row.calculable || row.lateMinutes > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              row.employeeId,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  row.empresa,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${row.sourceDate} · ${row.weekdayLabel}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.scheduledStart.isEmpty
                      ? 'Pendiente'
                      : '${row.scheduledStart} - ${row.scheduledEnd}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                if (row.scheduledLunch.isNotEmpty)
                  Text(
                    'Comida ${row.scheduledLunch}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.56),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              row.punchTimeline.isEmpty
                  ? 'Sin fichajes'
                  : row.punchTimeline.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: row.calculable
                ? Text(
                    _resolveTardinessMetricSummary(row),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.68),
                    ),
                  )
                : Text(
                    row.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.56),
                    ),
                  ),
          ),
          SizedBox(
            width: 120,
            child: Center(
              child: _HrStagePresencePill(
                label: row.statusLabel,
                positive: positive && !warning,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Center(
              child: _HrStagePresencePill(
                label: _resolveTardinessActionLabel(row),
                positive: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrAttendanceAbsenceRowTile extends StatelessWidget {
  final _HrAttendanceAbsenceRow row;

  const _HrAttendanceAbsenceRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              row.employeeId,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  row.empresa,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${row.sourceDate} · ${row.weekdayLabel}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.jornadaLabel.isEmpty ? 'Pendiente' : row.jornadaLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: _HrStagePresencePill(
                label: row.ngtecoStatus,
                positive: !row.hasOperationalAbsence,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: _HrStagePresencePill(
                label: row.contpaqStatus,
                positive: !row.hasAdministrativeSignal,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _HrStagePresencePill(
                label: row.statusLabel,
                positive: row.statusLabel == 'Vacaciones aplicadas',
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Center(
              child: _HrStagePresencePill(
                label: _resolveAbsenceActionLabel(row),
                positive: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrStagePresencePill extends StatelessWidget {
  final String label;
  final bool positive;

  const _HrStagePresencePill({required this.label, required this.positive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: positive ? const Color(0xFFDCC5FF) : const Color(0x33FFB4B4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: positive ? const Color(0xFF9F6BFF) : const Color(0x66FFB4B4),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: positive ? const Color(0xFF24103D) : const Color(0xFFFFE8E8),
        ),
      ),
    );
  }
}

String _hrStageStatusLabel(_HrAttendanceStageRow row) {
  if (row.missingScheduleBase || row.missingWorkdaysBase) {
    return 'Base pendiente';
  }
  if (row.requiresManualCapture) return 'Revisión';
  return 'Cruzado';
}

bool _hrStageStatusPositive(_HrAttendanceStageRow row) {
  if (row.missingScheduleBase || row.missingWorkdaysBase) return false;
  return !row.requiresManualCapture;
}

String _hrStageNextActionLabel(_HrAttendanceStageRow row) {
  if (row.missingScheduleBase || row.missingWorkdaysBase) {
    return 'Completar';
  }
  if (row.requiresManualCapture) return 'Revisar';
  return 'Ver';
}

bool _isRelevantTardinessRow(_HrAttendanceTardinessRow row) {
  if (row.statusLabel == 'Corregido RH') return true;
  if (!row.calculable) return false;
  return row.lateMinutes > 0 ||
      row.lunchLateMinutes > 0 ||
      row.overtimeMinutes > 0;
}

String _resolveTardinessMetricSummary(_HrAttendanceTardinessRow row) {
  if (!row.calculable) return row.reason;
  final parts = <String>[];
  parts.add('${row.lateMinutes} min');
  if (row.lateMinutes > 0) {
    parts.add('${row.lateHourEquivalent.toStringAsFixed(2)} h');
    parts.add('${(row.lateWorkdayRatio * 100).toStringAsFixed(2)}% jornada');
  }
  if (row.lunchLateMinutes > 0) {
    parts.add('Comida ${row.lunchLateMinutes}');
  }
  if (row.overtimeMinutes > 0) {
    parts.add('Extra ${row.overtimeMinutes}');
  }
  return parts.join(' · ');
}

String _resolveTardinessActionLabel(_HrAttendanceTardinessRow row) {
  if (row.statusLabel == 'Corregido RH') return 'Ver ajuste';
  if (!row.calculable) return 'Completar';
  if (row.statusLabel == 'Sin novedad') return 'Ver';
  return 'Revisar';
}

String _resolveAbsenceActionLabel(_HrAttendanceAbsenceRow row) {
  if (row.statusLabel == 'Corregido RH') return 'Ver ajuste';
  if (row.requiresReview) return 'Revisar';
  return 'Ver';
}

bool _matchesAttendanceSearch({
  required String query,
  required String employeeId,
  required String displayName,
  required String empresa,
}) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return employeeId.toLowerCase().contains(normalized) ||
      displayName.toLowerCase().contains(normalized) ||
      empresa.toLowerCase().contains(normalized);
}

class _HrAttendanceEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _HrAttendanceEmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: const Color(0xA625163A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x44B084FF)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF3A2558),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 28, color: const Color(0xFFCFAEFF)),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrAttendanceBrand extends StatelessWidget {
  const _HrAttendanceBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: humanResourcesAreaTokens.glow.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Center(child: DicsaLogoD(size: 36, progress: 1)),
        ),
        const SizedBox(width: 14),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Recursos Humanos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Importación y conciliación',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFFCFAEFF),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _HrAttendanceImportSource {
  ngteco('NGTeco'),
  contpaq('CONTPAQ');

  final String label;
  const _HrAttendanceImportSource(this.label);
}

class _HrAttendanceImportLot {
  final String id;
  final _HrAttendanceImportSource source;
  final String fileName;
  final DateTime importedAt;
  final int validRows;
  final int rejectedRows;
  final String periodLabel;
  final List<String> issues;
  final List<_HrAttendanceImportPreviewRow> previewRows;
  final Set<String> uniqueEmployeeIds;
  final List<_HrAttendanceImportedEntry> entries;

  const _HrAttendanceImportLot({
    required this.id,
    required this.source,
    required this.fileName,
    required this.importedAt,
    required this.validRows,
    required this.rejectedRows,
    required this.periodLabel,
    required this.issues,
    required this.previewRows,
    required this.uniqueEmployeeIds,
    required this.entries,
  });

  Map<String, dynamic> toRow() {
    return {
      'id': id,
      'source': source.name,
      'file_name': fileName,
      'imported_at': importedAt.toIso8601String(),
      'valid_rows': validRows,
      'rejected_rows': rejectedRows,
      'period_label': periodLabel,
      'issues': issues,
      'preview_rows': previewRows.map((row) => row.toJson()).toList(),
      'unique_employee_ids': uniqueEmployeeIds.toList(),
      'entries': entries.map((entry) => entry.toJson()).toList(),
    };
  }

  static _HrAttendanceImportLot fromRow(Map<String, dynamic> row) {
    final sourceName = (row['source'] ?? '').toString();
    final source = _HrAttendanceImportSource.values.firstWhere(
      (item) => item.name == sourceName,
      orElse: () => _HrAttendanceImportSource.ngteco,
    );
    return _HrAttendanceImportLot(
      id: (row['id'] ?? '').toString(),
      source: source,
      fileName: (row['file_name'] ?? '').toString(),
      importedAt:
          DateTime.tryParse((row['imported_at'] ?? '').toString()) ??
          DateTime.now(),
      validRows: _asInt(row['valid_rows']),
      rejectedRows: _asInt(row['rejected_rows']),
      periodLabel: (row['period_label'] ?? '').toString(),
      issues: (row['issues'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      previewRows: (row['preview_rows'] as List? ?? const [])
          .map((item) => _HrAttendanceImportPreviewRow.fromJson(_asMap(item)))
          .toList(growable: false),
      uniqueEmployeeIds: (row['unique_employee_ids'] as List? ?? const [])
          .map((item) => item.toString())
          .toSet(),
      entries: (row['entries'] as List? ?? const [])
          .map((item) => _HrAttendanceImportedEntry.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class _HrAttendanceImportPreviewRow {
  final String employeeId;
  final String name;
  final String detail;

  const _HrAttendanceImportPreviewRow({
    required this.employeeId,
    required this.name,
    required this.detail,
  });

  Map<String, dynamic> toJson() => {
    'employee_id': employeeId,
    'name': name,
    'detail': detail,
  };

  static _HrAttendanceImportPreviewRow fromJson(Map<String, dynamic> json) {
    return _HrAttendanceImportPreviewRow(
      employeeId: (json['employee_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
    );
  }
}

class _HrAttendanceImportedEntry {
  final String employeeId;
  final String sourceName;
  final String detail;
  final String sourceDate;
  final String sourceTime;
  final String salary;
  final String net;
  final String overtime;
  final String vacations;
  final String absenceDeduction;
  final String imss;
  final String infonavit;
  final String fonacot;

  const _HrAttendanceImportedEntry({
    required this.employeeId,
    required this.sourceName,
    required this.detail,
    this.sourceDate = '',
    this.sourceTime = '',
    this.salary = '',
    this.net = '',
    this.overtime = '',
    this.vacations = '',
    this.absenceDeduction = '',
    this.imss = '',
    this.infonavit = '',
    this.fonacot = '',
  });

  Map<String, dynamic> toJson() => {
    'employee_id': employeeId,
    'source_name': sourceName,
    'detail': detail,
    'source_date': sourceDate,
    'source_time': sourceTime,
    'salary': salary,
    'net': net,
    'overtime': overtime,
    'vacations': vacations,
    'absence_deduction': absenceDeduction,
    'imss': imss,
    'infonavit': infonavit,
    'fonacot': fonacot,
  };

  static _HrAttendanceImportedEntry fromJson(Map<String, dynamic> json) {
    return _HrAttendanceImportedEntry(
      employeeId: (json['employee_id'] ?? '').toString(),
      sourceName: (json['source_name'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      sourceDate: (json['source_date'] ?? '').toString(),
      sourceTime: (json['source_time'] ?? '').toString(),
      salary: (json['salary'] ?? '').toString(),
      net: (json['net'] ?? '').toString(),
      overtime: (json['overtime'] ?? '').toString(),
      vacations: (json['vacations'] ?? '').toString(),
      absenceDeduction: (json['absence_deduction'] ?? '').toString(),
      imss: (json['imss'] ?? '').toString(),
      infonavit: (json['infonavit'] ?? '').toString(),
      fonacot: (json['fonacot'] ?? '').toString(),
    );
  }
}

class _HrAttendanceEmployeeMaster {
  final String employeeId;
  final String displayName;
  final String empresa;
  final String horario;
  final List<String> diasLabora;
  final List<_HrAttendanceWorkSchedule> workSchedules;
  final String fechaIngreso;
  final String salario;

  const _HrAttendanceEmployeeMaster({
    required this.employeeId,
    required this.displayName,
    required this.empresa,
    required this.horario,
    required this.diasLabora,
    this.workSchedules = const <_HrAttendanceWorkSchedule>[],
    required this.fechaIngreso,
    required this.salario,
  });
}

class _HrAttendanceWorkSchedule {
  final String horario;
  final List<String> diasLabora;

  const _HrAttendanceWorkSchedule({
    required this.horario,
    this.diasLabora = const <String>[],
  });

  bool get isMeaningful =>
      horario.trim().isNotEmpty ||
      diasLabora.any((day) => day.trim().isNotEmpty);
}

class _HrAttendanceStageRow {
  final String employeeId;
  final String displayName;
  final String empresa;
  final String horario;
  final List<String> diasLabora;
  final String fechaIngreso;
  final bool presentInNgteco;
  final bool presentInContpaq;
  final bool requiresManualCapture;
  final bool missingScheduleBase;
  final bool missingWorkdaysBase;
  final String sourceNameNgteco;
  final String sourceNameContpaq;
  final int ngtecoPunchCount;
  final int ngtecoDaysCount;
  final String ngtecoFirstStamp;
  final String ngtecoLastStamp;
  final String contpaqSalary;
  final String contpaqNet;

  const _HrAttendanceStageRow({
    required this.employeeId,
    required this.displayName,
    required this.empresa,
    required this.horario,
    required this.diasLabora,
    required this.fechaIngreso,
    required this.presentInNgteco,
    required this.presentInContpaq,
    required this.requiresManualCapture,
    required this.missingScheduleBase,
    required this.missingWorkdaysBase,
    required this.sourceNameNgteco,
    required this.sourceNameContpaq,
    required this.ngtecoPunchCount,
    required this.ngtecoDaysCount,
    required this.ngtecoFirstStamp,
    required this.ngtecoLastStamp,
    required this.contpaqSalary,
    required this.contpaqNet,
  });
}

class _HrAttendanceTardinessRow {
  final String employeeId;
  final String displayName;
  final String empresa;
  final String sourceDate;
  final String weekdayLabel;
  final String horario;
  final String matchedScheduleLabel;
  final String scheduledStart;
  final String scheduledEnd;
  final String scheduledLunch;
  final String firstPunch;
  final String lunchOutPunch;
  final String lunchReturnPunch;
  final String lastPunch;
  final List<String> punchTimeline;
  final int lateMinutes;
  final int lunchLateMinutes;
  final int overtimeMinutes;
  final int effectiveWorkMinutes;
  final double lateHourEquivalent;
  final double lateWorkdayRatio;
  final bool calculable;
  final String statusLabel;
  final String reason;
  final String salarioBase;
  final String manualAdjustmentLabel;
  final String manualAdjustmentNotes;

  const _HrAttendanceTardinessRow({
    required this.employeeId,
    required this.displayName,
    required this.empresa,
    required this.sourceDate,
    required this.weekdayLabel,
    required this.horario,
    required this.matchedScheduleLabel,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.scheduledLunch,
    required this.firstPunch,
    required this.lunchOutPunch,
    required this.lunchReturnPunch,
    required this.lastPunch,
    required this.punchTimeline,
    required this.lateMinutes,
    required this.lunchLateMinutes,
    required this.overtimeMinutes,
    required this.effectiveWorkMinutes,
    required this.lateHourEquivalent,
    required this.lateWorkdayRatio,
    required this.calculable,
    required this.statusLabel,
    required this.reason,
    required this.salarioBase,
    this.manualAdjustmentLabel = '',
    this.manualAdjustmentNotes = '',
  });
}

class _HrAttendanceAbsenceRow {
  final String employeeId;
  final String displayName;
  final String empresa;
  final String sourceDate;
  final String weekdayLabel;
  final String jornadaLabel;
  final String statusLabel;
  final String ngtecoStatus;
  final String contpaqStatus;
  final String detail;
  final String weeklyContext;
  final bool requiresReview;
  final bool hasOperationalAbsence;
  final bool hasAdministrativeSignal;
  final String manualAdjustmentLabel;
  final String manualAdjustmentNotes;

  const _HrAttendanceAbsenceRow({
    required this.employeeId,
    required this.displayName,
    required this.empresa,
    required this.sourceDate,
    required this.weekdayLabel,
    required this.jornadaLabel,
    required this.statusLabel,
    required this.ngtecoStatus,
    required this.contpaqStatus,
    required this.detail,
    required this.weeklyContext,
    required this.requiresReview,
    required this.hasOperationalAbsence,
    required this.hasAdministrativeSignal,
    this.manualAdjustmentLabel = '',
    this.manualAdjustmentNotes = '',
  });
}

enum _HrAttendanceAdjustmentType {
  falta('Falta'),
  permiso('Permiso'),
  vacaciones('Vacaciones'),
  incapacidad('Incapacidad'),
  horasExtra('Horas extra'),
  ajusteManual('Ajuste manual');

  final String label;
  const _HrAttendanceAdjustmentType(this.label);
}

class _HrAttendanceManualAdjustment {
  final String id;
  final String periodLabel;
  final String employeeId;
  final String employeeName;
  final String sourceDate;
  final _HrAttendanceAdjustmentType adjustmentType;
  final String notes;
  final bool impactsPayroll;
  final DateTime createdAt;

  const _HrAttendanceManualAdjustment({
    required this.id,
    required this.periodLabel,
    required this.employeeId,
    required this.employeeName,
    required this.sourceDate,
    required this.adjustmentType,
    required this.notes,
    required this.impactsPayroll,
    required this.createdAt,
  });

  String get adjustmentTypeLabel => adjustmentType.label;

  Map<String, dynamic> toRow() => {
    'id': id,
    'period_label': periodLabel,
    'employee_id': employeeId,
    'employee_name': employeeName,
    'source_date': sourceDate,
    'adjustment_type': adjustmentType.name,
    'notes': notes,
    'impacts_payroll': impactsPayroll,
    'created_at': createdAt.toIso8601String(),
  };

  static _HrAttendanceManualAdjustment fromRow(Map<String, dynamic> row) {
    final typeName = (row['adjustment_type'] ?? '').toString();
    return _HrAttendanceManualAdjustment(
      id: (row['id'] ?? '').toString(),
      periodLabel: (row['period_label'] ?? '').toString(),
      employeeId: (row['employee_id'] ?? '').toString(),
      employeeName: (row['employee_name'] ?? '').toString(),
      sourceDate: (row['source_date'] ?? '').toString(),
      adjustmentType: _HrAttendanceAdjustmentType.values.firstWhere(
        (item) => item.name == typeName,
        orElse: () => _HrAttendanceAdjustmentType.ajusteManual,
      ),
      notes: (row['notes'] ?? '').toString(),
      impactsPayroll: row['impacts_payroll'] == true,
      createdAt:
          DateTime.tryParse((row['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

_HrAttendanceImportLot? _latestLotBySource(
  List<_HrAttendanceImportLot> lots,
  _HrAttendanceImportSource source,
) {
  for (final lot in lots) {
    if (lot.source == source) return lot;
  }
  return null;
}

List<_HrAttendanceStageRow> _buildAttendanceRows({
  required List<_HrAttendanceEmployeeMaster> employees,
  required _HrAttendanceImportLot? ngtecoLot,
  required _HrAttendanceImportLot? contpaqLot,
}) {
  final ngtecoEntries =
      ngtecoLot?.entries ?? const <_HrAttendanceImportedEntry>[];
  final ngtecoById = <String, List<_HrAttendanceImportedEntry>>{};
  for (final entry in ngtecoEntries) {
    ngtecoById
        .putIfAbsent(entry.employeeId, () => <_HrAttendanceImportedEntry>[])
        .add(entry);
  }
  final contpaqById = {
    for (final entry
        in contpaqLot?.entries ?? const <_HrAttendanceImportedEntry>[])
      entry.employeeId: entry,
  };

  return employees
      .map((employee) {
        final normalizedEmployeeId = _normalizeAttendanceEmployeeId(
          employee.employeeId,
        );
        final ngtecoEntriesForEmployee =
            ngtecoById[normalizedEmployeeId] ??
            const <_HrAttendanceImportedEntry>[];
        final ngtecoEntry = ngtecoEntriesForEmployee.isEmpty
            ? null
            : ngtecoEntriesForEmployee.first;
        final contpaqEntry = contpaqById[normalizedEmployeeId];
        final presentInNgteco = ngtecoEntry != null;
        final presentInContpaq = contpaqEntry != null;
        final ngtecoDates = <String>{
          for (final entry in ngtecoEntriesForEmployee)
            if (entry.sourceDate.trim().isNotEmpty) entry.sourceDate.trim(),
        };
        final sortedDateTimes =
            ngtecoEntriesForEmployee
                .map(_parseAttendanceImportedDateTime)
                .whereType<DateTime>()
                .toList(growable: false)
              ..sort();
        return _HrAttendanceStageRow(
          employeeId: employee.employeeId,
          displayName: employee.displayName,
          empresa: employee.empresa,
          horario: employee.horario,
          diasLabora: employee.diasLabora,
          fechaIngreso: employee.fechaIngreso,
          presentInNgteco: presentInNgteco,
          presentInContpaq: presentInContpaq,
          requiresManualCapture: !(presentInNgteco && presentInContpaq),
          missingScheduleBase: employee.workSchedules.every(
            (schedule) => schedule.horario.trim().isEmpty,
          ),
          missingWorkdaysBase: employee.workSchedules.isEmpty
              ? employee.diasLabora.isEmpty
              : employee.workSchedules.every(
                  (schedule) => schedule.diasLabora.isEmpty,
                ),
          sourceNameNgteco: ngtecoEntry?.sourceName ?? '',
          sourceNameContpaq: contpaqEntry?.sourceName ?? '',
          ngtecoPunchCount: ngtecoEntriesForEmployee.length,
          ngtecoDaysCount: ngtecoDates.length,
          ngtecoFirstStamp: sortedDateTimes.isEmpty
              ? ''
              : _fmtAttendanceDateTimeCompact(sortedDateTimes.first),
          ngtecoLastStamp: sortedDateTimes.isEmpty
              ? ''
              : _fmtAttendanceDateTimeCompact(sortedDateTimes.last),
          contpaqSalary: contpaqEntry?.salary ?? '',
          contpaqNet: contpaqEntry?.net ?? '',
        );
      })
      .toList(growable: false);
}

List<_HrAttendanceTardinessRow> _buildTardinessRows({
  required List<_HrAttendanceEmployeeMaster> employees,
  required _HrAttendanceImportLot? ngtecoLot,
  required List<_HrAttendanceManualAdjustment> adjustments,
}) {
  if (ngtecoLot == null) return const <_HrAttendanceTardinessRow>[];
  final adjustmentsByKey = _indexAttendanceAdjustments(adjustments);
  final employeesById = {
    for (final employee in employees)
      _normalizeAttendanceEmployeeId(employee.employeeId): employee,
  };
  final grouped = _groupAttendanceEntriesByEmployeeDay(ngtecoLot.entries);

  final rows = <_HrAttendanceTardinessRow>[];
  for (final record in grouped.entries) {
    final entries = record.value;
    if (entries.isEmpty) continue;
    final sample = entries.first;
    final employee = employeesById[sample.employeeId];
    if (employee == null) continue;
    final sorted =
        entries
            .map(_parseAttendanceImportedDateTime)
            .whereType<DateTime>()
            .toList(growable: false)
          ..sort();
    if (sorted.isEmpty) continue;
    final firstPunchAt = sorted.first;
    final sourceDate = _fmtAttendanceDateLabel(firstPunchAt);
    final weekdayLabel = _hrWeekdayLabel(firstPunchAt.weekday);
    final adjustment = adjustmentsByKey['${employee.employeeId}|$sourceDate'];
    final resolvedSchedule = _resolveAttendanceScheduleForPunch(
      schedules: employee.workSchedules,
      weekdayLabel: weekdayLabel,
      punchAt: firstPunchAt,
    );
    final schedule = resolvedSchedule?.schedule;
    final punchTimeline = sorted
        .map(_fmtAttendanceTime)
        .toList(growable: false);
    final lastPunchAt = sorted.last;
    final lunchOutAt = sorted.length >= 2 ? sorted[1] : null;
    final lunchReturnAt = sorted.length >= 3 ? sorted[2] : null;
    if (schedule == null) {
      rows.add(
        _HrAttendanceTardinessRow(
          employeeId: employee.employeeId,
          displayName: employee.displayName,
          empresa: employee.empresa,
          sourceDate: sourceDate,
          weekdayLabel: weekdayLabel,
          horario: employee.horario,
          matchedScheduleLabel: '',
          scheduledStart: '',
          scheduledEnd: '',
          scheduledLunch: '',
          firstPunch: _fmtAttendanceTime(firstPunchAt),
          lunchOutPunch: lunchOutAt == null
              ? ''
              : _fmtAttendanceTime(lunchOutAt),
          lunchReturnPunch: lunchReturnAt == null
              ? ''
              : _fmtAttendanceTime(lunchReturnAt),
          lastPunch: _fmtAttendanceTime(lastPunchAt),
          punchTimeline: punchTimeline,
          lateMinutes: 0,
          lunchLateMinutes: 0,
          overtimeMinutes: 0,
          effectiveWorkMinutes: 0,
          lateHourEquivalent: 0,
          lateWorkdayRatio: 0,
          calculable: false,
          statusLabel: adjustment == null ? 'Base pendiente' : 'Corregido RH',
          reason: adjustment == null
              ? employee.workSchedules.any(
                      (candidate) => candidate.horario.trim().isNotEmpty,
                    )
                    ? 'No hay jornada asignada para $weekdayLabel.'
                    : 'Falta horario para calcular retardo.'
              : _formatAttendanceAdjustmentSummary(adjustment),
          salarioBase: employee.salario,
          manualAdjustmentLabel: adjustment?.adjustmentTypeLabel ?? '',
          manualAdjustmentNotes: adjustment?.notes ?? '',
        ),
      );
      continue;
    }
    if (!resolvedSchedule!.worksThatDay) {
      rows.add(
        _HrAttendanceTardinessRow(
          employeeId: employee.employeeId,
          displayName: employee.displayName,
          empresa: employee.empresa,
          sourceDate: sourceDate,
          weekdayLabel: weekdayLabel,
          horario: resolvedSchedule.label,
          matchedScheduleLabel: resolvedSchedule.matchReason,
          scheduledStart: _fmtTimeOfDay(schedule.start),
          scheduledEnd: _fmtTimeOfDay(schedule.end),
          scheduledLunch: _formatScheduledLunch(schedule),
          firstPunch: _fmtAttendanceTime(firstPunchAt),
          lunchOutPunch: lunchOutAt == null
              ? ''
              : _fmtAttendanceTime(lunchOutAt),
          lunchReturnPunch: lunchReturnAt == null
              ? ''
              : _fmtAttendanceTime(lunchReturnAt),
          lastPunch: _fmtAttendanceTime(lastPunchAt),
          punchTimeline: punchTimeline,
          lateMinutes: 0,
          lunchLateMinutes: 0,
          overtimeMinutes: 0,
          effectiveWorkMinutes: _resolveEffectiveWorkMinutes(schedule),
          lateHourEquivalent: 0,
          lateWorkdayRatio: 0,
          calculable: false,
          statusLabel: adjustment == null ? 'Día no laborable' : 'Corregido RH',
          reason: adjustment == null
              ? 'Hay fichajes en una jornada que no marca este día como laborable.'
              : _formatAttendanceAdjustmentSummary(adjustment),
          salarioBase: employee.salario,
          manualAdjustmentLabel: adjustment?.adjustmentTypeLabel ?? '',
          manualAdjustmentNotes: adjustment?.notes ?? '',
        ),
      );
      continue;
    }
    final scheduledStartAt = DateTime(
      firstPunchAt.year,
      firstPunchAt.month,
      firstPunchAt.day,
      schedule.start.hour,
      schedule.start.minute,
    );
    final scheduledEndAt = DateTime(
      firstPunchAt.year,
      firstPunchAt.month,
      firstPunchAt.day,
      schedule.end.hour,
      schedule.end.minute,
    );
    final effectiveWorkMinutes = _resolveEffectiveWorkMinutes(schedule);
    final lateMinutes = firstPunchAt.difference(scheduledStartAt).inMinutes;
    final normalizedLateMinutes = lateMinutes > 0 ? lateMinutes : 0;
    final lunchLateMinutes = _resolveLunchLateMinutes(
      schedule: schedule,
      firstPunchAt: firstPunchAt,
      lunchReturnAt: lunchReturnAt,
    );
    final overtimeMinutes = _resolveOvertimeMinutes(
      scheduledEndAt: scheduledEndAt,
      lastPunchAt: lastPunchAt,
    );
    final lateHourEquivalent = normalizedLateMinutes / 60;
    final lateWorkdayRatio = effectiveWorkMinutes <= 0
        ? 0.0
        : normalizedLateMinutes / effectiveWorkMinutes;
    rows.add(
      _HrAttendanceTardinessRow(
        employeeId: employee.employeeId,
        displayName: employee.displayName,
        empresa: employee.empresa,
        sourceDate: sourceDate,
        weekdayLabel: weekdayLabel,
        horario: resolvedSchedule.label,
        matchedScheduleLabel: resolvedSchedule.matchReason,
        scheduledStart: _fmtTimeOfDay(schedule.start),
        scheduledEnd: _fmtTimeOfDay(schedule.end),
        scheduledLunch: _formatScheduledLunch(schedule),
        firstPunch: _fmtAttendanceTime(firstPunchAt),
        lunchOutPunch: lunchOutAt == null ? '' : _fmtAttendanceTime(lunchOutAt),
        lunchReturnPunch: lunchReturnAt == null
            ? ''
            : _fmtAttendanceTime(lunchReturnAt),
        lastPunch: _fmtAttendanceTime(lastPunchAt),
        punchTimeline: punchTimeline,
        lateMinutes: normalizedLateMinutes,
        lunchLateMinutes: lunchLateMinutes,
        overtimeMinutes: overtimeMinutes,
        effectiveWorkMinutes: effectiveWorkMinutes,
        lateHourEquivalent: lateHourEquivalent,
        lateWorkdayRatio: lateWorkdayRatio,
        calculable: true,
        statusLabel: adjustment == null
            ? _resolveTardinessStatusLabel(
                entryLateMinutes: normalizedLateMinutes,
                lunchLateMinutes: lunchLateMinutes,
                overtimeMinutes: overtimeMinutes,
              )
            : 'Corregido RH',
        reason: adjustment == null
            ? _resolveTardinessReason(
                entryLateMinutes: normalizedLateMinutes,
                lunchLateMinutes: lunchLateMinutes,
                overtimeMinutes: overtimeMinutes,
              )
            : _formatAttendanceAdjustmentSummary(adjustment),
        salarioBase: employee.salario,
        manualAdjustmentLabel: adjustment?.adjustmentTypeLabel ?? '',
        manualAdjustmentNotes: adjustment?.notes ?? '',
      ),
    );
  }

  rows.sort((a, b) {
    final aDate = _parseAttendanceDateLabel(a.sourceDate);
    final bDate = _parseAttendanceDateLabel(b.sourceDate);
    if (aDate != null && bDate != null) {
      final cmp = aDate.compareTo(bDate);
      if (cmp != 0) return cmp;
    }
    final lateCmp = b.lateMinutes.compareTo(a.lateMinutes);
    if (lateCmp != 0) return lateCmp;
    final idA = int.tryParse(a.employeeId);
    final idB = int.tryParse(b.employeeId);
    if (idA != null && idB != null) return idA.compareTo(idB);
    return a.employeeId.compareTo(b.employeeId);
  });
  return rows;
}

List<_HrAttendanceAbsenceRow> _buildAbsenceRows({
  required List<_HrAttendanceEmployeeMaster> employees,
  required _HrAttendanceImportLot? ngtecoLot,
  required _HrAttendanceImportLot? contpaqLot,
  required List<_HrAttendanceManualAdjustment> adjustments,
}) {
  if (ngtecoLot == null) return const <_HrAttendanceAbsenceRow>[];
  final adjustmentsByKey = _indexAttendanceAdjustments(adjustments);
  final contpaqById = {
    for (final entry
        in contpaqLot?.entries ?? const <_HrAttendanceImportedEntry>[])
      entry.employeeId: entry,
  };
  final grouped = _groupAttendanceEntriesByEmployeeDay(ngtecoLot.entries);
  final activeDates = _collectAttendanceActiveDates(ngtecoLot.entries);
  final sortedDates = activeDates.toList(growable: false)..sort();
  if (sortedDates.isEmpty) return const <_HrAttendanceAbsenceRow>[];

  final rows = <_HrAttendanceAbsenceRow>[];
  for (final employee in employees) {
    final normalizedEmployeeId = _normalizeAttendanceEmployeeId(
      employee.employeeId,
    );
    final employeeWeeklyPunches = grouped.entries
        .where((entry) => entry.key.startsWith('$normalizedEmployeeId|'))
        .fold<int>(0, (sum, entry) => sum + entry.value.length);
    final contpaqEntry = contpaqById[normalizedEmployeeId];
    final vacationAmount = _parseHrDecimalAmount(contpaqEntry?.vacations ?? '');
    final absenceAmount = _parseHrDecimalAmount(
      contpaqEntry?.absenceDeduction ?? '',
    );
    final overtimeAmount = _parseHrDecimalAmount(contpaqEntry?.overtime ?? '');
    final hasAdministrativeSignal =
        vacationAmount > 0 || absenceAmount > 0 || overtimeAmount > 0;
    for (final date in sortedDates) {
      final weekdayLabel = _hrWeekdayLabel(date.weekday);
      final resolvedSchedule = _resolveAttendanceScheduleForPunchlessDay(
        schedules: employee.workSchedules,
        weekdayLabel: weekdayLabel,
      );
      if (resolvedSchedule == null || !resolvedSchedule.worksThatDay) continue;
      final sourceDate = _fmtAttendanceDateLabel(date);
      final adjustment = adjustmentsByKey['${employee.employeeId}|$sourceDate'];
      final groupedKey = _attendanceEmployeeDayKey(normalizedEmployeeId, date);
      final punches =
          grouped[groupedKey] ?? const <_HrAttendanceImportedEntry>[];
      final hasPunches = punches.isNotEmpty;
      final ngtecoStatus = hasPunches ? 'Con fichaje' : 'Sin fichaje';
      final contpaqStatus = _resolveAbsenceContpaqStatus(
        vacations: vacationAmount,
        absenceDeduction: absenceAmount,
        overtime: overtimeAmount,
      );
      final detailParts = <String>[
        if (hasPunches)
          'Hay fichajes en NGTeco para el día laborable esperado.',
        if (!hasPunches)
          'No hay fichajes en NGTeco para un día laborable esperado.',
        if (vacationAmount > 0)
          'Vacaciones en CONTPAQ: ${contpaqEntry!.vacations}',
        if (absenceAmount > 0)
          'Falta en CONTPAQ: ${contpaqEntry!.absenceDeduction}',
        if (overtimeAmount > 0)
          'Horas extra en CONTPAQ: ${contpaqEntry!.overtime}',
      ];
      final requiresReview = !hasPunches || hasAdministrativeSignal;
      final statusLabel = adjustment == null
          ? _resolveAbsenceStatusLabel(
              hasPunches: hasPunches,
              vacations: vacationAmount,
              absenceDeduction: absenceAmount,
              overtime: overtimeAmount,
            )
          : 'Corregido RH';
      rows.add(
        _HrAttendanceAbsenceRow(
          employeeId: employee.employeeId,
          displayName: employee.displayName,
          empresa: employee.empresa,
          sourceDate: sourceDate,
          weekdayLabel: weekdayLabel,
          jornadaLabel: resolvedSchedule.label,
          statusLabel: statusLabel,
          ngtecoStatus: ngtecoStatus,
          contpaqStatus: contpaqStatus,
          detail: adjustment == null
              ? detailParts.join(' ')
              : _formatAttendanceAdjustmentSummary(adjustment),
          weeklyContext: hasPunches
              ? 'Con fichaje este día.'
              : employeeWeeklyPunches > 0
              ? 'Sin fichaje este día; sí hay registros en otros días de la semana.'
              : 'Sin fichajes en NGTeco durante la semana importada.',
          requiresReview: requiresReview,
          hasOperationalAbsence: !hasPunches,
          hasAdministrativeSignal: hasAdministrativeSignal,
          manualAdjustmentLabel: adjustment?.adjustmentTypeLabel ?? '',
          manualAdjustmentNotes: adjustment?.notes ?? '',
        ),
      );
    }
  }

  rows.sort((a, b) {
    final aDate = _parseAttendanceDateLabel(a.sourceDate);
    final bDate = _parseAttendanceDateLabel(b.sourceDate);
    if (aDate != null && bDate != null) {
      final cmp = aDate.compareTo(bDate);
      if (cmp != 0) return cmp;
    }
    if (a.hasOperationalAbsence != b.hasOperationalAbsence) {
      return a.hasOperationalAbsence ? -1 : 1;
    }
    final idA = int.tryParse(a.employeeId);
    final idB = int.tryParse(b.employeeId);
    if (idA != null && idB != null) return idA.compareTo(idB);
    return a.employeeId.compareTo(b.employeeId);
  });
  return rows;
}

_HrAttendanceImportLot _parseNgtecoImportLot(String fileName, List<int> bytes) {
  final content = _decodeImportText(bytes);
  final rows = _parseCsvRows(content);
  if (rows.isEmpty) {
    return _HrAttendanceImportLot(
      id: 'ngteco_${DateTime.now().microsecondsSinceEpoch}',
      source: _HrAttendanceImportSource.ngteco,
      fileName: fileName,
      importedAt: DateTime.now(),
      validRows: 0,
      rejectedRows: 0,
      periodLabel: '',
      issues: const ['Archivo CSV vacío'],
      previewRows: const [],
      uniqueEmployeeIds: const <String>{},
      entries: const [],
    );
  }
  final header = rows.first
      .map(_normalizeHrImportHeader)
      .toList(growable: false);
  final idIndex = header.indexOf('ID de Persona');
  final nameIndex = header.indexOf('Nombre de la Persona');
  final dateIndex = header.indexOf('Fecha de Fichaje');
  final timeIndex = header.indexOf('Registro de Asistencia');
  final issues = <String>[];
  if (idIndex == -1) issues.add('Falta columna ID de Persona');
  if (nameIndex == -1) issues.add('Falta columna Nombre de la Persona');
  if (dateIndex == -1) issues.add('Falta columna Fecha de Fichaje');
  if (timeIndex == -1) issues.add('Falta columna Registro de Asistencia');

  var validRows = 0;
  var rejectedRows = 0;
  final ids = <String>{};
  final preview = <_HrAttendanceImportPreviewRow>[];
  final entries = <_HrAttendanceImportedEntry>[];
  final dates = <String>{};

  for (final row in rows.skip(1)) {
    final rawEmployeeId = idIndex >= 0 && idIndex < row.length
        ? row[idIndex].trim()
        : '';
    final employeeId = _normalizeAttendanceEmployeeId(rawEmployeeId);
    final name = nameIndex >= 0 && nameIndex < row.length
        ? row[nameIndex].trim()
        : '';
    final date = dateIndex >= 0 && dateIndex < row.length
        ? row[dateIndex].trim()
        : '';
    final time = timeIndex >= 0 && timeIndex < row.length
        ? row[timeIndex].trim()
        : '';
    final hasAny = row.any((cell) => cell.trim().isNotEmpty);
    if (!hasAny) continue;
    if (employeeId.isEmpty || name.isEmpty || date.isEmpty || time.isEmpty) {
      rejectedRows += 1;
      continue;
    }
    validRows += 1;
    ids.add(employeeId);
    dates.add(date);
    entries.add(
      _HrAttendanceImportedEntry(
        employeeId: employeeId,
        sourceName: name,
        detail: '$date · $time',
        sourceDate: date,
        sourceTime: time,
      ),
    );
    if (preview.length < 6) {
      preview.add(
        _HrAttendanceImportPreviewRow(
          employeeId: employeeId,
          name: name,
          detail: '$date · $time',
        ),
      );
    }
  }

  final sortedDates =
      dates
          .map(_parseUsImportDate)
          .whereType<DateTime>()
          .toList(growable: false)
        ..sort();
  final periodLabel = sortedDates.isEmpty
      ? ''
      : sortedDates.length == 1
      ? _fmtAttendanceDateLabel(sortedDates.first)
      : '${_fmtAttendanceDateLabel(sortedDates.first)} → ${_fmtAttendanceDateLabel(sortedDates.last)}';
  return _HrAttendanceImportLot(
    id: 'ngteco_${DateTime.now().microsecondsSinceEpoch}',
    source: _HrAttendanceImportSource.ngteco,
    fileName: fileName,
    importedAt: DateTime.now(),
    validRows: validRows,
    rejectedRows: rejectedRows,
    periodLabel: periodLabel,
    issues: issues,
    previewRows: preview,
    uniqueEmployeeIds: ids,
    entries: entries,
  );
}

_HrAttendanceImportLot _parseContpaqImportLot(
  String fileName,
  List<int> bytes,
) {
  final workbook = _SimpleXlsxWorkbook.fromBytes(bytes);
  final rows = workbook.rows;
  final issues = <String>[];
  if (rows.isEmpty) {
    return _HrAttendanceImportLot(
      id: 'contpaq_${DateTime.now().microsecondsSinceEpoch}',
      source: _HrAttendanceImportSource.contpaq,
      fileName: fileName,
      importedAt: DateTime.now(),
      validRows: 0,
      rejectedRows: 0,
      periodLabel: workbook.periodLabel,
      issues: const ['Archivo XLSX sin filas utilizables'],
      previewRows: const [],
      uniqueEmployeeIds: const <String>{},
      entries: const [],
    );
  }
  final headerIndex = rows.indexWhere(
    (row) => row.contains('Código') && row.contains('Empleado'),
  );
  if (headerIndex == -1) {
    return _HrAttendanceImportLot(
      id: 'contpaq_${DateTime.now().microsecondsSinceEpoch}',
      source: _HrAttendanceImportSource.contpaq,
      fileName: fileName,
      importedAt: DateTime.now(),
      validRows: 0,
      rejectedRows: 0,
      periodLabel: workbook.periodLabel,
      issues: const ['No se encontró el header tabular de CONTPAQ'],
      previewRows: const [],
      uniqueEmployeeIds: const <String>{},
      entries: const [],
    );
  }
  final header = rows[headerIndex]
      .map(_normalizeHrImportHeader)
      .toList(growable: false);
  final idIndex = header.indexOf('Código');
  final employeeIndex = header.indexOf('Empleado');
  final salaryIndex = header.indexOf('Sueldo');
  final netIndex = header.indexOf('*NETO*');
  final overtimeIndex = header.indexOf('Horas extras');
  final vacationsIndex = header.indexOf('Vacaciones a tiempo');
  final absenceDeductionIndex = header.indexOf(
    'Falta sin obligacion empresarial',
  );
  final imssIndex = header.indexOf('I.M.S.S.');
  final infonavitIndex = header.indexOf('Préstamo infonavit (CF)');
  final fonacotIndex = header.indexOf('Préstamo FONACOT');

  var validRows = 0;
  var rejectedRows = 0;
  final ids = <String>{};
  final preview = <_HrAttendanceImportPreviewRow>[];
  final entries = <_HrAttendanceImportedEntry>[];
  for (final row in rows.skip(headerIndex + 1)) {
    final hasAny = row.any((cell) => cell.trim().isNotEmpty);
    if (!hasAny) continue;
    if (_isContpaqStructuralRow(row)) continue;
    final rawEmployeeId = idIndex >= 0 && idIndex < row.length
        ? row[idIndex].trim()
        : '';
    final employeeId = _normalizeAttendanceEmployeeId(rawEmployeeId);
    final name = employeeIndex >= 0 && employeeIndex < row.length
        ? row[employeeIndex].trim()
        : '';
    final salary = salaryIndex >= 0 && salaryIndex < row.length
        ? _formatContpaqAmount(row[salaryIndex].trim())
        : '';
    final net = netIndex >= 0 && netIndex < row.length
        ? _formatContpaqAmount(row[netIndex].trim())
        : '';
    final overtime = overtimeIndex >= 0 && overtimeIndex < row.length
        ? _formatContpaqAmount(row[overtimeIndex].trim())
        : '';
    final vacations = vacationsIndex >= 0 && vacationsIndex < row.length
        ? _formatContpaqAmount(row[vacationsIndex].trim())
        : '';
    final absenceDeduction =
        absenceDeductionIndex >= 0 && absenceDeductionIndex < row.length
        ? _formatContpaqAmount(row[absenceDeductionIndex].trim())
        : '';
    final imss = imssIndex >= 0 && imssIndex < row.length
        ? _formatContpaqAmount(row[imssIndex].trim())
        : '';
    final infonavit = infonavitIndex >= 0 && infonavitIndex < row.length
        ? _formatContpaqAmount(row[infonavitIndex].trim())
        : '';
    final fonacot = fonacotIndex >= 0 && fonacotIndex < row.length
        ? _formatContpaqAmount(row[fonacotIndex].trim())
        : '';
    if (employeeId.isEmpty || name.isEmpty) {
      rejectedRows += 1;
      continue;
    }
    validRows += 1;
    ids.add(employeeId);
    final detailParts = <String>[
      'Sueldo $salary',
      'Neto $net',
      if (_parseHrDecimalAmount(vacations) > 0) 'Vacaciones $vacations',
      if (_parseHrDecimalAmount(absenceDeduction) > 0)
        'Falta $absenceDeduction',
      if (_parseHrDecimalAmount(overtime) > 0) 'Extras $overtime',
      if (_parseHrDecimalAmount(imss) > 0) 'IMSS $imss',
      if (_parseHrDecimalAmount(infonavit) > 0) 'INFONAVIT $infonavit',
      if (_parseHrDecimalAmount(fonacot) > 0) 'FONACOT $fonacot',
    ];
    entries.add(
      _HrAttendanceImportedEntry(
        employeeId: employeeId,
        sourceName: name,
        detail: detailParts.join(' · '),
        salary: salary,
        net: net,
        overtime: overtime,
        vacations: vacations,
        absenceDeduction: absenceDeduction,
        imss: imss,
        infonavit: infonavit,
        fonacot: fonacot,
      ),
    );
    if (preview.length < 6) {
      preview.add(
        _HrAttendanceImportPreviewRow(
          employeeId: employeeId,
          name: name,
          detail: detailParts.join(' · '),
        ),
      );
    }
  }
  if (salaryIndex == -1) issues.add('Falta columna Sueldo');
  if (netIndex == -1) issues.add('Falta columna *NETO*');
  if (overtimeIndex == -1) issues.add('Falta columna Horas extras');
  if (vacationsIndex == -1) issues.add('Falta columna Vacaciones a tiempo');
  if (absenceDeductionIndex == -1) {
    issues.add('Falta columna Falta sin obligacion empresarial');
  }
  if (imssIndex == -1) issues.add('Falta columna I.M.S.S.');
  if (infonavitIndex == -1) {
    issues.add('Falta columna Préstamo infonavit (CF)');
  }
  if (fonacotIndex == -1) issues.add('Falta columna Préstamo FONACOT');

  return _HrAttendanceImportLot(
    id: 'contpaq_${DateTime.now().microsecondsSinceEpoch}',
    source: _HrAttendanceImportSource.contpaq,
    fileName: fileName,
    importedAt: DateTime.now(),
    validRows: validRows,
    rejectedRows: rejectedRows,
    periodLabel: workbook.periodLabel,
    issues: issues,
    previewRows: preview,
    uniqueEmployeeIds: ids,
    entries: entries,
  );
}

String _decodeImportText(List<int> bytes) {
  try {
    return const Utf8Decoder(allowMalformed: true).convert(bytes);
  } catch (_) {
    return latin1.decode(bytes, allowInvalid: true);
  }
}

String _normalizeHrImportHeader(String value) {
  return value.replaceFirst('\uFEFF', '').trim();
}

List<List<String>> _parseCsvRows(String raw) {
  final lines = const LineSplitter().convert(raw.replaceAll('\r\n', '\n'));
  return lines
      .where((line) => line.trim().isNotEmpty)
      .map(_parseCsvLine)
      .toList(growable: false);
}

List<String> _parseCsvLine(String line) {
  final cells = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i += 1;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      cells.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  cells.add(buffer.toString());
  return cells;
}

String _fmtHrImportDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

DateTime? _parseAttendanceImportedDateTime(_HrAttendanceImportedEntry entry) {
  final date = entry.sourceDate.trim();
  final time = entry.sourceTime.trim();
  if (date.isEmpty || time.isEmpty) return null;
  final dateMatch = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(date);
  final timeMatch = RegExp(
    r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$',
  ).firstMatch(time);
  if (dateMatch == null || timeMatch == null) return null;
  final month = int.tryParse(dateMatch.group(1)!);
  final day = int.tryParse(dateMatch.group(2)!);
  final year = int.tryParse(dateMatch.group(3)!);
  final hour = int.tryParse(timeMatch.group(1)!);
  final minute = int.tryParse(timeMatch.group(2)!);
  final second = int.tryParse(timeMatch.group(3) ?? '0');
  if (month == null ||
      day == null ||
      year == null ||
      hour == null ||
      minute == null ||
      second == null) {
    return null;
  }
  return DateTime(year, month, day, hour, minute, second);
}

Map<String, List<_HrAttendanceImportedEntry>>
_groupAttendanceEntriesByEmployeeDay(List<_HrAttendanceImportedEntry> entries) {
  final grouped = <String, List<_HrAttendanceImportedEntry>>{};
  for (final entry in entries) {
    final parsedDate = _parseAttendanceImportedDateTime(entry);
    if (parsedDate == null) continue;
    final key = _attendanceEmployeeDayKey(entry.employeeId, parsedDate);
    grouped.putIfAbsent(key, () => <_HrAttendanceImportedEntry>[]).add(entry);
  }
  return grouped;
}

Set<DateTime> _collectAttendanceActiveDates(
  List<_HrAttendanceImportedEntry> entries,
) {
  final activeDates = <DateTime>{};
  for (final entry in entries) {
    final parsedDate = _parseAttendanceImportedDateTime(entry);
    if (parsedDate == null) continue;
    activeDates.add(
      DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
    );
  }
  return activeDates;
}

String _attendanceEmployeeDayKey(String employeeId, DateTime date) {
  final normalizedEmployeeId = _normalizeAttendanceEmployeeId(employeeId);
  final normalizedDate = DateTime(date.year, date.month, date.day);
  final year = normalizedDate.year.toString().padLeft(4, '0');
  final month = normalizedDate.month.toString().padLeft(2, '0');
  final day = normalizedDate.day.toString().padLeft(2, '0');
  return '$normalizedEmployeeId|$year-$month-$day';
}

String _fmtAttendanceDateTimeCompact(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$minute';
}

String _fmtAttendanceDateLabel(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}

DateTime? _parseAttendanceDateLabel(String raw) {
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(raw.trim());
  if (match == null) return null;
  final day = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

DateTime? _parseUsImportDate(String raw) {
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(raw.trim());
  if (match == null) return null;
  final month = int.tryParse(match.group(1)!);
  final day = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

String _fmtAttendanceTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _hrWeekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Lun';
    case DateTime.tuesday:
      return 'Mar';
    case DateTime.wednesday:
      return 'Mie';
    case DateTime.thursday:
      return 'Jue';
    case DateTime.friday:
      return 'Vie';
    case DateTime.saturday:
      return 'Sab';
    case DateTime.sunday:
      return 'Dom';
    default:
      return '';
  }
}

_HrAttendanceScheduleDraft? _parseAttendanceSchedule(String? raw) {
  final normalized = (raw ?? '').trim();
  final pattern = RegExp(
    r'^(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2})(?:\s*\|\s*comida\s*(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2}))?$',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(normalized);
  if (match == null) return null;
  final start = _parseAttendanceTimeOfDay(match.group(1));
  final end = _parseAttendanceTimeOfDay(match.group(2));
  if (start == null || end == null) return null;
  return _HrAttendanceScheduleDraft(
    start: start,
    end: end,
    lunchStart: _parseAttendanceTimeOfDay(match.group(3)),
    lunchEnd: _parseAttendanceTimeOfDay(match.group(4)),
  );
}

int _resolveEffectiveWorkMinutes(_HrAttendanceScheduleDraft schedule) {
  final startMinutes = schedule.start.hour * 60 + schedule.start.minute;
  final endMinutes = schedule.end.hour * 60 + schedule.end.minute;
  var total = endMinutes - startMinutes;
  if (schedule.lunchStart != null && schedule.lunchEnd != null) {
    final lunchStartMinutes =
        schedule.lunchStart!.hour * 60 + schedule.lunchStart!.minute;
    final lunchEndMinutes =
        schedule.lunchEnd!.hour * 60 + schedule.lunchEnd!.minute;
    total -= (lunchEndMinutes - lunchStartMinutes);
  }
  return total > 0 ? total : 0;
}

int _resolveLunchLateMinutes({
  required _HrAttendanceScheduleDraft schedule,
  required DateTime firstPunchAt,
  required DateTime? lunchReturnAt,
}) {
  if (schedule.lunchEnd == null || lunchReturnAt == null) return 0;
  final lunchEndAt = DateTime(
    firstPunchAt.year,
    firstPunchAt.month,
    firstPunchAt.day,
    schedule.lunchEnd!.hour,
    schedule.lunchEnd!.minute,
  );
  final diff = lunchReturnAt.difference(lunchEndAt).inMinutes;
  return diff > 0 ? diff : 0;
}

int _resolveOvertimeMinutes({
  required DateTime scheduledEndAt,
  required DateTime lastPunchAt,
}) {
  final diff = lastPunchAt.difference(scheduledEndAt).inMinutes;
  return diff > 0 ? diff : 0;
}

String _formatScheduledLunch(_HrAttendanceScheduleDraft schedule) {
  if (schedule.lunchStart == null || schedule.lunchEnd == null) return '';
  return '${_fmtTimeOfDay(schedule.lunchStart!)} - ${_fmtTimeOfDay(schedule.lunchEnd!)}';
}

class _HrResolvedAttendanceSchedule {
  final _HrAttendanceScheduleDraft schedule;
  final bool worksThatDay;
  final String label;
  final String matchReason;
  final int score;

  const _HrResolvedAttendanceSchedule({
    required this.schedule,
    required this.worksThatDay,
    required this.label,
    required this.matchReason,
    required this.score,
  });
}

_HrResolvedAttendanceSchedule? _resolveAttendanceScheduleForPunch({
  required List<_HrAttendanceWorkSchedule> schedules,
  required String weekdayLabel,
  required DateTime punchAt,
}) {
  if (schedules.isEmpty) return null;
  final candidates = <_HrResolvedAttendanceSchedule>[];
  for (final item in schedules) {
    final parsed = _parseAttendanceSchedule(item.horario);
    if (parsed == null) continue;
    final startAt = DateTime(
      punchAt.year,
      punchAt.month,
      punchAt.day,
      parsed.start.hour,
      parsed.start.minute,
    );
    final diffMinutes = punchAt.difference(startAt).inMinutes.abs();
    final worksThatDay = item.diasLabora.contains(weekdayLabel);
    final hasWorkdays = item.diasLabora.isNotEmpty;
    final score = worksThatDay
        ? 0
        : hasWorkdays
        ? 10000 + diffMinutes
        : 5000 + diffMinutes;
    candidates.add(
      _HrResolvedAttendanceSchedule(
        schedule: parsed,
        worksThatDay: worksThatDay,
        label: item.horario,
        matchReason: hasWorkdays
            ? 'Jornada ${item.diasLabora.join(', ')}'
            : 'Jornada sin días fijos',
        score: score,
      ),
    );
  }
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => a.score.compareTo(b.score));
  return candidates.first;
}

_HrResolvedAttendanceSchedule? _resolveAttendanceScheduleForPunchlessDay({
  required List<_HrAttendanceWorkSchedule> schedules,
  required String weekdayLabel,
}) {
  if (schedules.isEmpty) return null;
  for (final item in schedules) {
    final parsed = _parseAttendanceSchedule(item.horario);
    if (parsed == null) continue;
    final worksThatDay = item.diasLabora.contains(weekdayLabel);
    if (!worksThatDay) continue;
    return _HrResolvedAttendanceSchedule(
      schedule: parsed,
      worksThatDay: true,
      label: item.horario,
      matchReason: 'Jornada ${item.diasLabora.join(', ')}',
      score: 0,
    );
  }
  return null;
}

double _parseHrDecimalAmount(String raw) {
  final normalized = raw.trim().replaceAll(',', '');
  if (normalized.isEmpty) return 0;
  return double.tryParse(normalized) ?? 0;
}

String _resolveAbsenceContpaqStatus({
  required double vacations,
  required double absenceDeduction,
  required double overtime,
}) {
  final labels = <String>[];
  if (vacations > 0) labels.add('Vacaciones');
  if (absenceDeduction > 0) labels.add('Falta aplicada');
  if (overtime > 0) labels.add('Extras aplicadas');
  if (labels.isEmpty) return 'Sin incidencia';
  return labels.join(' · ');
}

String _resolveAbsenceStatusLabel({
  required bool hasPunches,
  required double vacations,
  required double absenceDeduction,
  required double overtime,
}) {
  final hasVacations = vacations > 0;
  final hasAbsence = absenceDeduction > 0;
  final hasExtras = overtime > 0;
  if (hasPunches && !hasVacations && !hasAbsence && !hasExtras) {
    return 'Sin novedad';
  }
  if (!hasPunches && hasVacations) return 'Vacaciones aplicadas';
  if (!hasPunches && hasAbsence) return 'Falta aplicada';
  if (!hasPunches && !hasVacations && !hasAbsence && !hasExtras) {
    return 'Falta probable';
  }
  if (hasPunches && (hasVacations || hasAbsence || hasExtras)) {
    return 'Solo señal administrativa';
  }
  if (!hasPunches && hasExtras) return 'Ausencia por revisar';
  return 'Ausencia por revisar';
}

String _resolveActiveAttendancePeriodLabel({
  required _HrAttendanceImportLot? ngtecoLot,
  required _HrAttendanceImportLot? contpaqLot,
}) {
  final ngteco = ngtecoLot?.periodLabel.trim() ?? '';
  if (ngteco.isNotEmpty) return ngteco;
  return contpaqLot?.periodLabel.trim() ?? '';
}

Map<String, _HrAttendanceManualAdjustment> _indexAttendanceAdjustments(
  List<_HrAttendanceManualAdjustment> adjustments,
) {
  return {
    for (final adjustment in adjustments)
      '${adjustment.employeeId}|${adjustment.sourceDate}': adjustment,
  };
}

String _formatAttendanceAdjustmentSummary(
  _HrAttendanceManualAdjustment adjustment,
) {
  final note = adjustment.notes.trim();
  if (note.isEmpty) return 'Corrección RH: ${adjustment.adjustmentTypeLabel}.';
  return 'Corrección RH: ${adjustment.adjustmentTypeLabel} · $note';
}

String _resolveTardinessStatusLabel({
  required int entryLateMinutes,
  required int lunchLateMinutes,
  required int overtimeMinutes,
}) {
  final hasEntryLate = entryLateMinutes > 0;
  final hasLunchLate = lunchLateMinutes > 0;
  final hasOvertime = overtimeMinutes > 0;
  if (hasEntryLate && hasLunchLate && hasOvertime) return 'Mixto';
  if ((hasEntryLate && hasLunchLate) ||
      (hasEntryLate && hasOvertime) ||
      (hasLunchLate && hasOvertime)) {
    return 'Mixto';
  }
  if (hasEntryLate) return 'Retardo';
  if (hasLunchLate) return 'Comida tarde';
  if (hasOvertime) return 'Con extra';
  return 'Sin novedad';
}

String _resolveTardinessReason({
  required int entryLateMinutes,
  required int lunchLateMinutes,
  required int overtimeMinutes,
}) {
  final segments = <String>[];
  if (entryLateMinutes > 0) {
    segments.add('Entrada $entryLateMinutes min tarde');
  }
  if (lunchLateMinutes > 0) {
    segments.add('Comida $lunchLateMinutes min tarde');
  }
  if (overtimeMinutes > 0) {
    segments.add('Extra $overtimeMinutes min');
  }
  if (segments.isEmpty) {
    return 'Sin incidencias de tiempo detectadas.';
  }
  return segments.join(' · ');
}

TimeOfDay? _parseAttendanceTimeOfDay(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _fmtTimeOfDay(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatContpaqAmount(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final normalized = trimmed.replaceAll(',', '');
  final parsed = double.tryParse(normalized);
  if (parsed == null) return trimmed;
  return parsed.toStringAsFixed(2);
}

String _fmtHrCurrency(String raw) {
  final normalized = raw.trim().replaceAll(',', '');
  if (normalized.isEmpty) return '';
  final parsed = double.tryParse(normalized);
  if (parsed == null) return raw;
  final sign = parsed < 0 ? '-' : '';
  final fixed = parsed.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts.first;
  final decimal = parts.last;
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final reverseIndex = whole.length - i;
    buffer.write(whole[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return '$sign\$$buffer.$decimal';
}

String _describeImportPeriod(_HrAttendanceImportLot lot) {
  final raw = lot.periodLabel.trim();
  if (raw.isEmpty) return 'Periodo no detectado';
  if (lot.source == _HrAttendanceImportSource.ngteco) {
    final segments = raw.split('→').map((part) => part.trim()).toList();
    if (segments.length == 2) {
      final first = _parseUsImportDate(segments[0]);
      final second = _parseUsImportDate(segments[1]);
      if (first != null && second != null) {
        final ordered = [first, second]..sort();
        return '${_fmtAttendanceDateLabel(ordered.first)} - ${_fmtAttendanceDateLabel(ordered.last)}';
      }
    }
    return raw;
  }

  final periodMatch = RegExp(
    r'Periodo\s+(\d+)\s+al\s+\d+\s+Semanal\s+del\s+(\d{2}/\d{2}/\d{4})\s+al\s+(\d{2}/\d{2}/\d{4})(?:\s+·\s+Hora:\s+(\d{2}:\d{2}:\d{2}))?',
    caseSensitive: false,
  ).firstMatch(raw);
  if (periodMatch != null) {
    final week = periodMatch.group(1)!;
    final start = periodMatch.group(2)!;
    final end = periodMatch.group(3)!;
    final time = periodMatch.group(4);
    return time == null
        ? 'Periodo $week semanal · $start - $end'
        : 'Periodo $week semanal · $start - $end · Archivo $time';
  }
  return raw;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String _normalizeAttendanceEmployeeId(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  if (!RegExp(r'^\d+$').hasMatch(trimmed)) return trimmed;
  final normalized = trimmed.replaceFirst(RegExp(r'^0+'), '');
  return normalized.isEmpty ? '0' : normalized;
}

bool _isContpaqStructuralRow(List<String> row) {
  final first = row.isNotEmpty ? row.first.trim() : '';
  final second = row.length > 1 ? row[1].trim() : '';
  if (first.isEmpty && second.isEmpty) return false;
  if (first.startsWith('Reg. Pat. IMSS:')) return true;
  if (first.startsWith('Departamento ')) return true;
  if (first.startsWith('Total Depto')) return true;
  if (first.startsWith('Total Gral.')) return true;
  if (first.startsWith('----------------') ||
      second.startsWith('----------------')) {
    return true;
  }
  if (first.startsWith('=============') || second.startsWith('=============')) {
    return true;
  }
  final trailingCells = row
      .skip(2)
      .map((cell) => cell.trim())
      .toList(growable: false);
  if (first.isEmpty &&
      second.isEmpty &&
      trailingCells.any((cell) => cell.isNotEmpty)) {
    final allSeparators = trailingCells.every(
      (cell) =>
          cell.isEmpty ||
          cell.startsWith('----------------') ||
          cell.startsWith('============='),
    );
    if (allSeparators) return true;
    final allNumericLike = trailingCells.every(
      (cell) =>
          cell.isEmpty ||
          RegExp(r'^[\d\s.,-]+$').hasMatch(cell) ||
          cell.startsWith('----------------') ||
          cell.startsWith('============='),
    );
    if (allNumericLike) return true;
  }
  return false;
}

class _SimpleXlsxWorkbook {
  final List<List<String>> rows;
  final String periodLabel;

  const _SimpleXlsxWorkbook({required this.rows, required this.periodLabel});

  static _SimpleXlsxWorkbook fromBytes(List<int> bytes) {
    const mainNs = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
    const relNs =
        'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
    const pkgRelNs =
        'http://schemas.openxmlformats.org/package/2006/relationships';

    final archive = ZipDecoder().decodeBytes(bytes);
    String readText(String path) {
      final file = archive.findFile(path);
      if (file == null) throw StateError('Falta $path en el XLSX');
      return utf8.decode(_archiveFileBytes(file));
    }

    final workbook = XmlDocument.parse(readText('xl/workbook.xml'));
    final rels = XmlDocument.parse(readText('xl/_rels/workbook.xml.rels'));
    final sharedStrings = <String>[];
    final sharedFile = archive.findFile('xl/sharedStrings.xml');
    if (sharedFile != null) {
      final shared = XmlDocument.parse(
        utf8.decode(_archiveFileBytes(sharedFile)),
      );
      for (final si in shared.findAllElements('si', namespace: mainNs)) {
        sharedStrings.add(
          si
              .findAllElements('t', namespace: mainNs)
              .map((e) => e.innerText)
              .join(),
        );
      }
    }

    final sheets = workbook
        .findAllElements('sheet', namespace: mainNs)
        .toList();
    if (sheets.isEmpty) {
      throw StateError('El XLSX no contiene hojas de trabajo');
    }
    final firstSheet = sheets.first;
    final relationshipId =
        _xmlAttribute(firstSheet, 'id', namespace: relNs) ??
        _xmlAttribute(firstSheet, 'r:id') ??
        '';
    if (relationshipId.isEmpty) {
      throw StateError('No se encontró la relación de la primera hoja');
    }
    final relationships = rels
        .findAllElements('Relationship', namespace: pkgRelNs)
        .toList();
    final sheetRelationship = relationships.cast<XmlElement?>().firstWhere(
      (rel) => _xmlAttribute(rel, 'Id') == relationshipId,
      orElse: () => null,
    );
    final relTarget = _xmlAttribute(sheetRelationship, 'Target') ?? '';
    if (relTarget.isEmpty) {
      throw StateError('No se encontró el target de la hoja principal');
    }
    final sheetPath = relTarget.startsWith('xl/') ? relTarget : 'xl/$relTarget';
    final sheet = XmlDocument.parse(readText(sheetPath));
    final dataRows = <List<String>>[];
    final allRows = sheet.findAllElements('row', namespace: mainNs);

    for (final row in allRows) {
      var maxColumn = -1;
      var runningColumn = -1;
      for (final cell in row.findElements('c', namespace: mainNs)) {
        final reference = cell.getAttribute('r') ?? '';
        final column = reference.isNotEmpty
            ? _xlsxColumnIndex(reference)
            : runningColumn + 1;
        if (column > maxColumn) maxColumn = column;
        runningColumn = column;
      }
      if (maxColumn < 0) {
        dataRows.add(const <String>[]);
        continue;
      }
      final cells = List<String>.filled(maxColumn + 1, '', growable: false);
      runningColumn = -1;
      for (final cell in row.findElements('c', namespace: mainNs)) {
        final reference = cell.getAttribute('r') ?? '';
        final column = reference.isNotEmpty
            ? _xlsxColumnIndex(reference)
            : runningColumn + 1;
        final type = cell.getAttribute('t') ?? '';
        final valueElement = cell.getElement('v', namespace: mainNs);
        var value = valueElement?.innerText ?? '';
        if (type == 's' && value.isNotEmpty) {
          final index = int.tryParse(value);
          if (index != null && index >= 0 && index < sharedStrings.length) {
            value = sharedStrings[index];
          }
        } else if (type == 'inlineStr') {
          value =
              cell
                  .getElement('is', namespace: mainNs)
                  ?.findAllElements('t', namespace: mainNs)
                  .map((node) => node.innerText)
                  .join() ??
              '';
        }
        cells[column] = value;
        runningColumn = column;
      }
      dataRows.add(cells);
    }

    final periodLabel = dataRows.length > 3 && dataRows[3].isNotEmpty
        ? dataRows[3].where((cell) => cell.trim().isNotEmpty).join(' · ')
        : '';
    return _SimpleXlsxWorkbook(rows: dataRows, periodLabel: periodLabel);
  }
}

class _HrAttendanceScheduleDraft {
  final TimeOfDay start;
  final TimeOfDay end;
  final TimeOfDay? lunchStart;
  final TimeOfDay? lunchEnd;

  const _HrAttendanceScheduleDraft({
    required this.start,
    required this.end,
    this.lunchStart,
    this.lunchEnd,
  });
}

List<int> _archiveFileBytes(ArchiveFile file) {
  return file.content;
}

String? _xmlAttribute(XmlElement? element, String name, {String? namespace}) {
  if (element == null) return null;
  final direct = element.getAttribute(name, namespace: namespace);
  if (direct != null) return direct;
  if (!name.contains(':')) {
    for (final attribute in element.attributes) {
      if (attribute.name.local == name) return attribute.value;
    }
  }
  final qualified = element.getAttribute(name);
  return qualified;
}

int _xlsxColumnIndex(String reference) {
  final letters = reference.replaceAll(RegExp(r'[^A-Z]'), '');
  var result = 0;
  for (final codeUnit in letters.codeUnits) {
    result = result * 26 + (codeUnit - 64);
  }
  return result - 1;
}

List<String> _parseAttendanceWeekdays(Object? value) {
  if (value == null) return const <String>[];
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final text = value.toString().trim();
  if (text.isEmpty) return const <String>[];
  return text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<_HrAttendanceWorkSchedule> _parseAttendanceWorkSchedules(
  Object? value, {
  String fallbackHorario = '',
  List<String> fallbackDiasLabora = const <String>[],
}) {
  final parsed = <_HrAttendanceWorkSchedule>[];
  if (value is List) {
    for (final item in value) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final schedule = _HrAttendanceWorkSchedule(
          horario: (map['horario'] ?? '').toString(),
          diasLabora: _parseAttendanceWeekdays(map['dias_labora']),
        );
        if (schedule.isMeaningful) parsed.add(schedule);
      }
    }
  }
  if (parsed.isNotEmpty) return parsed;
  final fallback = _HrAttendanceWorkSchedule(
    horario: fallbackHorario,
    diasLabora: fallbackDiasLabora,
  );
  return fallback.isMeaningful
      ? <_HrAttendanceWorkSchedule>[fallback]
      : const <_HrAttendanceWorkSchedule>[];
}
