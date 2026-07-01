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
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_buttons.dart';
import 'human_resources_area_chrome.dart';
import 'human_resources_dashboard_page.dart';
import 'human_resources_personnel_page.dart';
import 'human_resources_theme.dart';

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

  late final OperacionHibridaTabsController _tabs =
      OperacionHibridaTabsController(initialTabId: 'resumen');

  bool _menuOpen = false;
  bool _canReturnToDirection = false;
  bool _loadingSummary = true;
  int _employeeCount = 0;
  List<_HrAttendanceEmployeeMaster> _employees =
      const <_HrAttendanceEmployeeMaster>[];
  bool _importingNgteco = false;
  bool _importingContpaq = false;
  final List<_HrAttendanceImportLot> _importLots = <_HrAttendanceImportLot>[];

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadSummary());
    unawaited(_loadSavedImportLots());
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
      final result = await Supabase.instance.client
          .from(_kProfilesTable)
          .select(
            'id,nombre,empresa,horario,dias_labora,labor_schedules,fecha_ingreso,salario',
          );
      if (!mounted) return;
      final rows =
          (result as List)
              .map((raw) => Map<String, dynamic>.from(raw as Map))
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
      final result = await Supabase.instance.client
          .from(_kImportLotsTable)
          .select()
          .order('imported_at', ascending: false);
      if (!mounted) return;
      final lots = (result as List)
          .map((raw) => Map<String, dynamic>.from(raw as Map))
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
                    onImportNgteco: () =>
                        _pickImportFile(_HrAttendanceImportSource.ngteco),
                    onImportContpaq: () =>
                        _pickImportFile(_HrAttendanceImportSource.contpaq),
                    importingNgteco: _importingNgteco,
                    importingContpaq: _importingContpaq,
                    onDeleteLot: _deleteImportLot,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_menuOpen,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _menuOpen ? 1 : 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _menuOpen = false),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: _menuOpen ? 0 : -332,
              top: 0,
              bottom: 0,
              width: 320,
              child: IgnorePointer(
                ignoring: !_menuOpen,
                child: HumanResourcesAreaSidePanel(
                  label: 'Recursos Humanos',
                  canReturnToDirection: _canReturnToDirection,
                  areaItems: [
                    HumanResourcesAreaNavEntry(
                      icon: Icons.space_dashboard_rounded,
                      title: 'Dashboard RH',
                      subtitle: 'Resumen y contexto del área',
                      onTap: _openDashboard,
                    ),
                    HumanResourcesAreaNavEntry(
                      icon: Icons.badge_outlined,
                      title: 'Personal',
                      subtitle: 'Expediente operativo y adscripción',
                      onTap: _openPersonnel,
                    ),
                    const HumanResourcesAreaNavEntry(
                      icon: Icons.schedule_rounded,
                      title: 'Asistencia e incidencias',
                      subtitle: 'Importaciones, staging y correcciones',
                      accented: true,
                    ),
                  ],
                  accessItems: [
                    if (_canReturnToDirection)
                      HumanResourcesAreaNavEntry(
                        icon: Icons.assessment_outlined,
                        title: 'Dashboard Dirección',
                        subtitle: 'Vista ejecutiva multiarea',
                        onTap: _openDirectionDashboard,
                      ),
                  ],
                ),
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
  final Future<void> Function() onImportNgteco;
  final Future<void> Function() onImportContpaq;
  final bool importingNgteco;
  final bool importingContpaq;
  final Future<void> Function(_HrAttendanceImportLot lot) onDeleteLot;

  const _HrAttendanceWorkspace({
    required this.tabs,
    required this.loadingSummary,
    required this.employeeCount,
    required this.employees,
    required this.importLots,
    required this.onImportNgteco,
    required this.onImportContpaq,
    required this.importingNgteco,
    required this.importingContpaq,
    required this.onDeleteLot,
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
    final attendanceRows = _buildAttendanceRows(
      employees: employees,
      ngtecoLot: latestNgteco,
      contpaqLot: latestContpaq,
    );
    final tardinessRows = _buildTardinessRows(
      employees: employees,
      ngtecoLot: latestNgteco,
    );
    final importedNgteco = _countImportedEmployees(
      importLots,
      _HrAttendanceImportSource.ngteco,
    );
    final importedContpaq = _countImportedEmployees(
      importLots,
      _HrAttendanceImportSource.contpaq,
    );
    final manualRequired = employeeCount - importedNgteco < 0
        ? 0
        : employeeCount - importedNgteco;
    final pendingReview = importLots.fold<int>(
      0,
      (sum, lot) => sum + lot.rejectedRows,
    );
    final tabsSpec = const [
      ('resumen', 'Resumen'),
      ('importaciones', 'Importaciones'),
      ('asistencia', 'Asistencia'),
      ('retardos', 'Retardos'),
      ('faltas', 'Faltas y ausencias'),
      ('permisos', 'Permisos y vacaciones'),
      ('correcciones', 'Correcciones'),
    ];

    return AnimatedBuilder(
      animation: tabs,
      builder: (context, _) {
        return OperacionHibridaTabsShell(
          topBar: _HrAttendanceTopBar(activeTabId: tabs.activeTabId),
          summary: _HrAttendanceSummaryStrip(
            loading: loadingSummary,
            employeeCount: employeeCount,
            importedNgteco: importedNgteco,
            importedContpaq: importedContpaq,
            manualRequired: manualRequired,
            pendingReview: pendingReview,
          ),
          actionsBar: _HrAttendanceActionsBar(
            activeTabId: tabs.activeTabId,
            onImportNgteco: onImportNgteco,
            onImportContpaq: onImportContpaq,
            importingNgteco: importingNgteco,
            importingContpaq: importingContpaq,
          ),
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
              'resumen': _HrAttendancePanel(
                title: 'Resumen semanal',
                subtitle:
                    'Cruce por ID, cobertura de fuentes y puntos pendientes antes de publicar a prenómina.',
                child: _HrAttendanceOverviewBody(
                  employeeCount: employeeCount,
                  importedNgteco: importedNgteco,
                  importedContpaq: importedContpaq,
                  attendanceRows: attendanceRows,
                ),
              ),
              'importaciones': _HrAttendancePanel(
                title: 'Importaciones',
                subtitle:
                    'Sube NGTeco y CONTPAQ a staging. Ningún lote pega directo a prenómina.',
                child: _HrAttendanceImportationsBody(
                  lots: importLots,
                  onImportNgteco: onImportNgteco,
                  onImportContpaq: onImportContpaq,
                  importingNgteco: importingNgteco,
                  importingContpaq: importingContpaq,
                  onDeleteLot: onDeleteLot,
                ),
              ),
              'asistencia': _HrAttendancePanel(
                title: 'Asistencia',
                subtitle:
                    'Vista semanal por colaborador con horario esperado, presencia en fuentes y estado de revisión.',
                child: _HrAttendanceStagingBody(
                  rows: attendanceRows,
                  ngtecoPeriodLabel: latestNgteco?.periodLabel ?? '',
                  contpaqPeriodLabel: latestContpaq?.periodLabel ?? '',
                ),
              ),
              'retardos': _HrAttendancePanel(
                title: 'Retardos',
                subtitle:
                    'Minutos tarde, proporción respecto a jornada efectiva y descuento potencial reproducible.',
                child: _HrAttendanceTardinessBody(
                  rows: tardinessRows,
                  ngtecoPeriodLabel: latestNgteco?.periodLabel ?? '',
                ),
              ),
              'faltas': const _HrAttendancePanel(
                title: 'Faltas y ausencias',
                subtitle:
                    'Control semanal de faltas justificadas, injustificadas y horas ausentes.',
                child: _HrAttendanceEmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'Sin staging de ausencias',
                  body:
                      'Aquí se consolidarán faltas, ausencias parciales y justificaciones antes del envío a prenómina.',
                ),
              ),
              'permisos': const _HrAttendancePanel(
                title: 'Permisos y vacaciones',
                subtitle:
                    'Permisos, vacaciones e incapacidades sobre la misma semana operacional.',
                child: _HrAttendanceEmptyState(
                  icon: Icons.beach_access_outlined,
                  title: 'Módulo en preparación',
                  body:
                      'Esta vista concentrará permisos, vacaciones e incapacidades manuales o importadas para la semana de trabajo.',
                ),
              ),
              'correcciones': const _HrAttendancePanel(
                title: 'Correcciones',
                subtitle:
                    'Ajustes manuales, otras plantas y casos donde no existe cobertura completa de NGTeco o CONTPAQ.',
                child: _HrAttendanceEmptyState(
                  icon: Icons.edit_calendar_outlined,
                  title: 'Correcciones manuales pendientes',
                  body:
                      'Aquí RH podrá capturar horas, retardos, permisos y observaciones cuando el colaborador no venga en una fuente o requiera ajuste.',
                ),
              ),
            },
          ),
        );
      },
    );
  }
}

class _HrAttendanceTopBar extends StatelessWidget {
  final String activeTabId;

  const _HrAttendanceTopBar({required this.activeTabId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xE625163A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9F6BFF), Color(0xFF6E47A8)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Asistencia e incidencias',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _hrAttendanceSubtitleFor(activeTabId),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.72),
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

String _hrAttendanceSubtitleFor(String tabId) {
  switch (tabId) {
    case 'importaciones':
      return 'Carga NGTeco y CONTPAQ con staging auditable.';
    case 'asistencia':
      return 'Consolidación semanal por colaborador y cobertura de fuentes.';
    case 'retardos':
      return 'Minutos tarde y equivalencias reproducibles de descuento.';
    case 'faltas':
      return 'Control de faltas, ausencias y revisión semanal.';
    case 'permisos':
      return 'Permisos, vacaciones e incapacidades sobre el periodo.';
    case 'correcciones':
      return 'Captura manual para plantas, casos parciales y ajustes.';
    case 'resumen':
    default:
      return 'Capa previa a prenómina para validar asistencia e incidencias.';
  }
}

class _HrAttendanceSummaryStrip extends StatelessWidget {
  final bool loading;
  final int employeeCount;
  final int importedNgteco;
  final int importedContpaq;
  final int manualRequired;
  final int pendingReview;

  const _HrAttendanceSummaryStrip({
    required this.loading,
    required this.employeeCount,
    required this.importedNgteco,
    required this.importedContpaq,
    required this.manualRequired,
    required this.pendingReview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xC61D112F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _HrAttendanceMetricCard(
            icon: Icons.badge_outlined,
            label: 'Padrón RH',
            value: loading ? '...' : '$employeeCount',
            subtitle: 'Base maestra del periodo',
          ),
          _HrAttendanceMetricCard(
            icon: Icons.fingerprint_rounded,
            label: 'NGTeco',
            value: '$importedNgteco',
            subtitle: 'Con fichaje cargado',
          ),
          _HrAttendanceMetricCard(
            icon: Icons.payments_outlined,
            label: 'CONTPAQ',
            value: '$importedContpaq',
            subtitle: 'Presentes en nómina',
          ),
          _HrAttendanceMetricCard(
            icon: Icons.edit_calendar_outlined,
            label: 'Captura manual',
            value: loading ? '...' : '$manualRequired',
            subtitle: 'Requieren atención RH',
          ),
          _HrAttendanceMetricCard(
            icon: Icons.rule_folder_outlined,
            label: 'Pendiente revisión',
            value: '$pendingReview',
            subtitle: 'Sin publicar a prenómina',
          ),
        ],
      ),
    );
  }
}

class _HrAttendanceActionsBar extends StatelessWidget {
  final String activeTabId;
  final Future<void> Function() onImportNgteco;
  final Future<void> Function() onImportContpaq;
  final bool importingNgteco;
  final bool importingContpaq;

  const _HrAttendanceActionsBar({
    required this.activeTabId,
    required this.onImportNgteco,
    required this.onImportContpaq,
    required this.importingNgteco,
    required this.importingContpaq,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xC61D112F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            style: contractPrimaryButtonStyle(context),
            onPressed: activeTabId == 'importaciones' ? onImportNgteco : null,
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(
              importingNgteco ? 'Cargando NGTeco...' : 'Importar NGTeco',
            ),
          ),
          OutlinedButton.icon(
            style: contractSecondaryButtonStyle(context),
            onPressed: activeTabId == 'importaciones' ? onImportContpaq : null,
            icon: const Icon(Icons.table_view_rounded),
            label: Text(
              importingContpaq ? 'Cargando CONTPAQ...' : 'Importar CONTPAQ',
            ),
          ),
          OutlinedButton.icon(
            style: contractSecondaryButtonStyle(context),
            onPressed: null,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Captura manual'),
          ),
        ],
      ),
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
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _HrAttendanceOverviewBody extends StatelessWidget {
  final int employeeCount;
  final int importedNgteco;
  final int importedContpaq;
  final List<_HrAttendanceStageRow> attendanceRows;

  const _HrAttendanceOverviewBody({
    required this.employeeCount,
    required this.importedNgteco,
    required this.importedContpaq,
    required this.attendanceRows,
  });

  @override
  Widget build(BuildContext context) {
    final fullyCrossed = attendanceRows
        .where((row) => row.presentInNgteco && row.presentInContpaq)
        .length;
    final missingBase = attendanceRows
        .where((row) => row.missingScheduleBase || row.missingWorkdaysBase)
        .length;
    final withNgtecoPunches = attendanceRows
        .where((row) => row.ngtecoPunchCount > 0)
        .length;
    return ListView(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _HrAttendanceInfoCard(
              title: 'Regla madre',
              body:
                  'Asistencia e incidencias consolida, corrige y publica al staging semanal. No calcula nómina final.',
            ),
            _HrAttendanceInfoCard(
              title: 'Cobertura parcial permitida',
              body:
                  'La ausencia en NGTeco o CONTPAQ no es error automático. RH debe poder resolverlo con captura manual y trazabilidad.',
            ),
            _HrAttendanceInfoCard(
              title: 'Semana actual',
              body:
                  'Padrón RH: $employeeCount · NGTeco: $importedNgteco · CONTPAQ: $importedContpaq · Con fichajes visibles: $withNgtecoPunches.',
            ),
            _HrAttendanceInfoCard(
              title: 'Cruce por ID',
              body:
                  'Coinciden en ambas fuentes: $fullyCrossed · Requieren captura manual: ${attendanceRows.where((row) => row.requiresManualCapture).length} · Base de personal pendiente: $missingBase.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _HrAttendanceEmptyState(
          icon: Icons.account_tree_outlined,
          title: 'Staging semanal inicial activo',
          body:
              'La importación ya cruza IDs reales entre Personal, NGTeco y CONTPAQ. El siguiente bloque es cálculo operativo: retardos, faltas, permisos y correcciones manuales sobre esta misma semana.',
        ),
      ],
    );
  }
}

class _HrAttendanceImportationsBody extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _HrImportSourceCard(
              title: 'NGTeco',
              body:
                  'CSV de reloj checador. Usa employee_id como llave y aporta fichaje bruto por fecha/hora.',
              buttonLabel: importingNgteco ? 'Importando...' : 'Subir CSV',
              icon: Icons.fingerprint_rounded,
              onTap: importingNgteco ? null : onImportNgteco,
            ),
            _HrImportSourceCard(
              title: 'CONTPAQ',
              body:
                  'XLSX de lista de raya. Toma Código, Empleado y neto/percepciones para staging semanal.',
              buttonLabel: importingContpaq ? 'Importando...' : 'Subir XLSX',
              icon: Icons.payments_outlined,
              onTap: importingContpaq ? null : onImportContpaq,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (lots.isEmpty)
          const _HrAttendanceEmptyState(
            icon: Icons.upload_file_rounded,
            title: 'Sin lotes importados',
            body:
                'Sube un CSV de NGTeco o un XLSX de CONTPAQ para registrar el lote, contar filas válidas/rechazadas y abrir el staging inicial.',
          )
        else
          Column(
            children: [
              for (var i = 0; i < lots.length; i++) ...[
                _HrImportLotCard(
                  lot: lots[i],
                  onDelete: () => onDeleteLot(lots[i]),
                ),
                if (i != lots.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }
}

class _HrAttendanceStagingBody extends StatelessWidget {
  final List<_HrAttendanceStageRow> rows;
  final String ngtecoPeriodLabel;
  final String contpaqPeriodLabel;

  const _HrAttendanceStagingBody({
    required this.rows,
    required this.ngtecoPeriodLabel,
    required this.contpaqPeriodLabel,
  });

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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HrStatusChip(
              label: ngtecoPeriodLabel.isEmpty
                  ? 'NGTeco sin lote'
                  : 'NGTeco: $ngtecoPeriodLabel',
              complete: ngtecoPeriodLabel.isNotEmpty,
            ),
            _HrStatusChip(
              label: contpaqPeriodLabel.isEmpty
                  ? 'CONTPAQ sin lote'
                  : 'CONTPAQ: $contpaqPeriodLabel',
              complete: contpaqPeriodLabel.isNotEmpty,
            ),
            _HrStatusChip(
              label:
                  'Manual: ${rows.where((row) => row.requiresManualCapture).length}',
              complete: rows.where((row) => row.requiresManualCapture).isEmpty,
            ),
          ],
        ),
        const SizedBox(height: 12),
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
  final String ngtecoPeriodLabel;

  const _HrAttendanceTardinessBody({
    required this.rows,
    required this.ngtecoPeriodLabel,
  });

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
    final calculable = rows
        .where((row) => row.calculable)
        .toList(growable: false);
    final tardies = calculable
        .where((row) => row.lateMinutes > 0)
        .toList(growable: false);
    final lunchTardies = calculable
        .where((row) => row.lunchLateMinutes > 0)
        .toList(growable: false);
    final overtimeRows = calculable
        .where((row) => row.overtimeMinutes > 0)
        .toList(growable: false);
    final unresolved = rows
        .where((row) => !row.calculable)
        .toList(growable: false);
    final totalLateMinutes = tardies.fold<int>(
      0,
      (sum, row) => sum + row.lateMinutes,
    );
    final totalLunchLateMinutes = lunchTardies.fold<int>(
      0,
      (sum, row) => sum + row.lunchLateMinutes,
    );
    final totalOvertimeMinutes = overtimeRows.fold<int>(
      0,
      (sum, row) => sum + row.overtimeMinutes,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HrStatusChip(
              label: ngtecoPeriodLabel.isEmpty
                  ? 'NGTeco sin lote'
                  : 'NGTeco: $ngtecoPeriodLabel',
              complete: ngtecoPeriodLabel.isNotEmpty,
            ),
            _HrStatusChip(
              label: 'Calculables: ${calculable.length}',
              complete: calculable.isNotEmpty,
            ),
            _HrStatusChip(
              label: 'Con retardo: ${tardies.length}',
              complete: tardies.isNotEmpty,
            ),
            _HrStatusChip(
              label: 'Min tarde: $totalLateMinutes',
              complete: totalLateMinutes == 0,
            ),
            _HrStatusChip(
              label: 'Comida tarde: $totalLunchLateMinutes min',
              complete: totalLunchLateMinutes == 0,
            ),
            _HrStatusChip(
              label:
                  'Horas extra: ${_fmtHrDecimal(totalOvertimeMinutes / 60)} h',
              complete: totalOvertimeMinutes == 0,
            ),
            _HrStatusChip(
              label: 'Base pendiente: ${unresolved.length}',
              complete: unresolved.isEmpty,
            ),
          ],
        ),
        const SizedBox(height: 12),
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

class _HrAttendanceMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;

  const _HrAttendanceMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 168),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xE625163A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x44B084FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF3A2558),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFCFAEFF)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.70),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ],
      ),
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
      width: 360,
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
  final Future<void> Function() onDelete;

  const _HrImportLotCard({required this.lot, required this.onDelete});

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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _HrStatusChip(label: lot.source.label, complete: true),
              _HrStatusChip(label: lot.fileName, complete: true),
              if (lot.periodLabel.isNotEmpty)
                _HrStatusChip(label: lot.periodLabel, complete: true),
              OutlinedButton.icon(
                style: contractSecondaryButtonStyle(context),
                onPressed: () async => onDelete(),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Borrar'),
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
          const SizedBox(height: 4),
          Text(
            'Importado ${_fmtHrImportDateTime(lot.importedAt)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.64),
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
          if (lot.previewRows.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0x8B140B25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Column(
                children: [
                  _HrImportPreviewHeader(source: lot.source),
                  for (var i = 0; i < lot.previewRows.length; i++)
                    _HrImportPreviewRowTile(
                      row: lot.previewRows[i],
                      isLast: i == lot.previewRows.length - 1,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HrImportPreviewHeader extends StatelessWidget {
  final _HrAttendanceImportSource source;

  const _HrImportPreviewHeader({required this.source});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2558),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 90,
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
            child: Text(
              'Nombre fuente',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: Text(
              source == _HrAttendanceImportSource.ngteco
                  ? 'Fecha / hora'
                  : 'Neto / sueldo',
              textAlign: TextAlign.right,
              style: const TextStyle(
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

class _HrImportPreviewRowTile extends StatelessWidget {
  final _HrAttendanceImportPreviewRow row;
  final bool isLast;

  const _HrImportPreviewRowTile({required this.row, required this.isLast});

  @override
  Widget build(BuildContext context) {
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
            width: 90,
            child: Text(
              row.employeeId,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.76),
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: Text(
              row.detail,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.68),
              ),
            ),
          ),
        ],
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
              'Empresa / horario',
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
            width: 132,
            child: Text(
              'Acción RH',
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
              '${row.empresa.isEmpty ? 'Empresa pendiente' : row.empresa}${row.horario.isEmpty ? '' : ' · ${row.horario}'}',
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
                      'Sueldo ${row.contpaqSalary}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.66),
                      ),
                    ),
                  if (row.contpaqNet.isNotEmpty)
                    Text(
                      'Neto ${row.contpaqNet}',
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
            width: 132,
            child: Center(
              child: _HrStagePresencePill(
                label: _hrStageActionLabel(row),
                positive: _hrStageActionPositive(row),
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
              'Fecha',
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
              'Jornada esperada',
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
              'Ocurrió ese día',
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
              'Hallazgos',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(
            width: 148,
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
                if (row.matchedScheduleLabel.trim().isNotEmpty)
                  Text(
                    row.matchedScheduleLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
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
                const SizedBox(height: 2),
                Text(
                  _resolveTardinessEventSummary(row),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
            child: row.calculable
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Entrada ${row.lateMinutes} min · ${_fmtHrDecimal(row.lateHourEquivalent)} h',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                      Text(
                        'Comida ${row.lunchLateMinutes} min · Extra ${row.overtimeMinutes} min',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.56),
                        ),
                      ),
                      Text(
                        '${_fmtHrPercent(row.lateWorkdayRatio)} de jornada efectiva',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.56),
                        ),
                      ),
                    ],
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
            width: 148,
            child: Center(
              child: _HrStagePresencePill(
                label: row.statusLabel,
                positive: positive && !warning,
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

String _hrStageActionLabel(_HrAttendanceStageRow row) {
  if (row.missingScheduleBase || row.missingWorkdaysBase) {
    return 'Completar personal';
  }
  if (row.requiresManualCapture) return 'Manual';
  return 'Cruzado';
}

bool _hrStageActionPositive(_HrAttendanceStageRow row) {
  if (row.missingScheduleBase || row.missingWorkdaysBase) return false;
  return !row.requiresManualCapture;
}

class _HrAttendanceInfoCard extends StatelessWidget {
  final String title;
  final String body;

  const _HrAttendanceInfoCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xE625163A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x44B084FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.70),
            ),
          ),
        ],
      ),
    );
  }
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
          ),
          child: const Icon(
            Icons.schedule_rounded,
            color: Color(0xFFCFAEFF),
            size: 28,
          ),
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
              'Asistencia e incidencias',
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

  const _HrAttendanceImportedEntry({
    required this.employeeId,
    required this.sourceName,
    required this.detail,
    this.sourceDate = '',
    this.sourceTime = '',
    this.salary = '',
    this.net = '',
  });

  Map<String, dynamic> toJson() => {
    'employee_id': employeeId,
    'source_name': sourceName,
    'detail': detail,
    'source_date': sourceDate,
    'source_time': sourceTime,
    'salary': salary,
    'net': net,
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
  });
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

int _countImportedEmployees(
  List<_HrAttendanceImportLot> lots,
  _HrAttendanceImportSource source,
) {
  final ids = <String>{};
  for (final lot in lots.where((lot) => lot.source == source)) {
    ids.addAll(lot.uniqueEmployeeIds);
  }
  return ids.length;
}

List<_HrAttendanceTardinessRow> _buildTardinessRows({
  required List<_HrAttendanceEmployeeMaster> employees,
  required _HrAttendanceImportLot? ngtecoLot,
}) {
  if (ngtecoLot == null) return const <_HrAttendanceTardinessRow>[];
  final employeesById = {
    for (final employee in employees)
      _normalizeAttendanceEmployeeId(employee.employeeId): employee,
  };
  final grouped = <String, List<_HrAttendanceImportedEntry>>{};
  for (final entry in ngtecoLot.entries) {
    if (entry.sourceDate.trim().isEmpty) continue;
    final key = '${entry.employeeId}|${entry.sourceDate.trim()}';
    grouped.putIfAbsent(key, () => <_HrAttendanceImportedEntry>[]).add(entry);
  }

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
    final weekdayLabel = _hrWeekdayLabel(firstPunchAt.weekday);
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
          sourceDate: _fmtAttendanceDateLabel(firstPunchAt),
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
          statusLabel: 'Base pendiente',
          reason:
              employee.workSchedules.any(
                (candidate) => candidate.horario.trim().isNotEmpty,
              )
              ? 'No hay jornada asignada para $weekdayLabel.'
              : 'Falta horario para calcular retardo.',
          salarioBase: employee.salario,
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
          sourceDate: _fmtAttendanceDateLabel(firstPunchAt),
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
          statusLabel: 'Día no laborable',
          reason:
              'Hay fichajes en una jornada que no marca este día como laborable.',
          salarioBase: employee.salario,
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
        sourceDate: _fmtAttendanceDateLabel(firstPunchAt),
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
        statusLabel: _resolveTardinessStatusLabel(
          entryLateMinutes: normalizedLateMinutes,
          lunchLateMinutes: lunchLateMinutes,
          overtimeMinutes: overtimeMinutes,
        ),
        reason: _resolveTardinessReason(
          entryLateMinutes: normalizedLateMinutes,
          lunchLateMinutes: lunchLateMinutes,
          overtimeMinutes: overtimeMinutes,
        ),
        salarioBase: employee.salario,
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
  final header = rows.first;
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

  final periodLabel = dates.isEmpty
      ? ''
      : dates.length == 1
      ? dates.first
      : '${dates.first} → ${dates.last}';
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
  final header = rows[headerIndex];
  final idIndex = header.indexOf('Código');
  final employeeIndex = header.indexOf('Empleado');
  final salaryIndex = header.indexOf('Sueldo');
  final netIndex = header.indexOf('*NETO*');

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
    if (employeeId.isEmpty || name.isEmpty) {
      rejectedRows += 1;
      continue;
    }
    validRows += 1;
    ids.add(employeeId);
    entries.add(
      _HrAttendanceImportedEntry(
        employeeId: employeeId,
        sourceName: name,
        detail: 'Sueldo $salary · Neto $net',
        salary: salary,
        net: net,
      ),
    );
    if (preview.length < 6) {
      preview.add(
        _HrAttendanceImportPreviewRow(
          employeeId: employeeId,
          name: name,
          detail: 'Sueldo $salary · Neto $net',
        ),
      );
    }
  }
  if (salaryIndex == -1) issues.add('Falta columna Sueldo');
  if (netIndex == -1) issues.add('Falta columna *NETO*');

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

String _fmtAttendanceTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _fmtHrDecimal(double value) => value.toStringAsFixed(2);

String _fmtHrPercent(double ratio) => '${(ratio * 100).toStringAsFixed(2)}%';

String _resolveTardinessEventSummary(_HrAttendanceTardinessRow row) {
  final segments = <String>[];
  if (row.firstPunch.isNotEmpty) {
    segments.add('Entrada ${row.firstPunch}');
  }
  if (row.lunchOutPunch.isNotEmpty) {
    segments.add('Comida sale ${row.lunchOutPunch}');
  }
  if (row.lunchReturnPunch.isNotEmpty) {
    segments.add('Comida regresa ${row.lunchReturnPunch}');
  }
  if (row.lastPunch.isNotEmpty && row.lastPunch != row.firstPunch) {
    segments.add('Salida ${row.lastPunch}');
  }
  return segments.isEmpty ? 'Sin eventos interpretados' : segments.join(' · ');
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

class _HrStatusChip extends StatelessWidget {
  final String label;
  final bool complete;

  const _HrStatusChip({required this.label, required this.complete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: complete ? const Color(0xFFDCC5FF) : const Color(0xFFF7F0FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: complete ? const Color(0xFF9F6BFF) : const Color(0x44B084FF),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: complete ? const Color(0xFF24103D) : const Color(0xFF6E47A8),
        ),
      ),
    );
  }
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
