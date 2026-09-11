import 'human_resources_fiscal_payment.dart';
import 'human_resources_fiscal_payment_card.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import '../shared/utils/file_download_save.dart';
import 'human_resources_area_chrome.dart';
import 'human_resources_terminations_page.dart';
import 'human_resources_loans_page.dart';
import 'human_resources_attendance_incidents_page.dart';
import 'human_resources_attendance_page.dart';
import 'human_resources_dashboard_page.dart';
import 'human_resources_permissions_page.dart';
import 'human_resources_personnel_page.dart';
import 'human_resources_period_context.dart';
import 'human_resources_prenomina_page.dart';
import 'human_resources_theme.dart';
import 'human_resources_vacations_page.dart';

part 'nomina/nomina_dashboard.dart';
part 'nomina/nomina_detail.dart';
part 'nomina/nomina_widgets.dart';
part 'nomina/nomina_test_support.dart';
part 'nomina/nomina_period_pdf.dart';

const String _kHrNominaDraftRowsTable = 'hr_prenomina_draft_rows';
const String _kHrNominaImportLotsTable = 'hr_attendance_import_lots';
const String _kHrNominaPeriodClosuresTable = 'hr_payroll_period_closures';
const String _kHrNominaReceiptDocumentsTable = 'hr_payroll_receipt_documents';
const String _kHrNominaReceiptBucket = 'hr_payroll_receipts';

class HumanResourcesNominaPage extends StatefulWidget {
  final bool instantOpen;

  const HumanResourcesNominaPage({super.key, this.instantOpen = false});

  @override
  State<HumanResourcesNominaPage> createState() =>
      _HumanResourcesNominaPageState();
}

class _HumanResourcesNominaPageState extends State<HumanResourcesNominaPage> {
  bool _menuOpen = false;
  bool _canReturnToDirection = false;
  bool _loading = true;
  String _activePeriodLabel = '';
  List<String> _periodOptions = const <String>[];
  String? _selectedRowId;
  int _currentPage = 0;
  int _pageSize = 40;
  final _searchController = TextEditingController();
  final Set<String> _statusFilters = {};
  String? _companyFilter;

  List<_HrNominaSummaryRow> get _filteredRows => _allRows
      .where((row) {
        final query = _searchController.text.trim().toLowerCase();
        return (query.isEmpty ||
                '${row.employeeId} ${row.employeeName}'.toLowerCase().contains(
                  query,
                )) &&
            (_statusFilters.isEmpty ||
                _statusFilters.contains(row.statusLabel)) &&
            (_companyFilter == null || row.empresa == _companyFilter);
      })
      .toList(growable: false);

  void _applyFilters() {
    _currentPage = 0;
    _rebuildVisibleRows();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_HrNominaSummaryRow> _allRows = const <_HrNominaSummaryRow>[];
  List<_HrNominaSummaryRow> _visibleRows = const <_HrNominaSummaryRow>[];
  List<_HrNominaDraftRecord> _draftRows = const <_HrNominaDraftRecord>[];
  List<_HrNominaPeriodClosure> _periodClosures =
      const <_HrNominaPeriodClosure>[];

  _HrNominaPeriodClosure? get _activePeriodClosure {
    for (final closure in _periodClosures) {
      if (closure.periodLabel == _activePeriodLabel) return closure;
    }
    return null;
  }

  bool get _isActivePeriodClosed => _activePeriodClosure?.isClosed ?? false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadData());
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(
      () =>
          _canReturnToDirection = AuthAccess.canAccessGeneralDashboard(profile),
    );
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final selectedPeriodLabel =
          await HumanResourcesPeriodContext.readSelectedLabel();
      final client = Supabase.instance.client;
      final draftRowsResult = await fetchAllSupabaseRows(
        (from, to) => client
            .from(_kHrNominaDraftRowsTable)
            .select(
              'id,created_at,period_label,employee_id,employee_name,empresa,draft_status,'
              'manual_adjustment_amount,fiscal_net_amount,fiscal_manual_deduction_amount,fiscal_manual_deduction_reason,cash_salary_amount,cash_vacation_amount,'
              'fiscal_late_deduction_amount,'
              'cash_isr_amount,transport_support_amount,holiday_amount,overtime_monetized_amount,'
              'manual_bonus_amount,cash_absence_deduction_amount,cash_infonavit_deduction_amount,'
              'cash_fonacot_deduction_amount,loan_deduction_amount,check_amount,payment_outside_amount,'
              'payment_channel,payment_reference,notes,source_snapshot',
            )
            .order('created_at', ascending: false)
            .range(from, to),
      );
      final profilesResult = await fetchAllSupabaseRows(
        (from, to) => client
            .from('hr_employee_profiles')
            .select('id,fiscal_payment_mode')
            .order('id')
            .range(from, to),
      );
      final fiscalModes = <String, String>{
        for (final profile in profilesResult)
          profile['id'].toString(): profile['fiscal_payment_mode'].toString(),
      };
      final importLotsResult = await fetchAllSupabaseRows(
        (from, to) => client
            .from(_kHrNominaImportLotsTable)
            .select('id,source,period_label,imported_at')
            .order('imported_at', ascending: false)
            .range(from, to),
      );
      List<dynamic> periodClosuresResult = const <dynamic>[];
      try {
        periodClosuresResult = await fetchAllSupabaseRows(
          (from, to) => client
              .from(_kHrNominaPeriodClosuresTable)
              .select()
              .order('created_at', ascending: false)
              .range(from, to),
        );
      } catch (_) {}

      final draftRows = draftRowsResult
          .map(_HrNominaDraftRecord.fromRow)
          .toList(growable: false);
      final importLots = importLotsResult
          .map(
            (raw) => _HrNominaImportLotLite.fromRow(
              Map<String, dynamic>.from(raw as Map),
            ),
          )
          .toList(growable: false);
      final periodClosures = periodClosuresResult
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map(_HrNominaPeriodClosure.fromRow)
          .toList(growable: false);

      final periodOptions = _nominaPeriodOptions(
        drafts: draftRows,
        lots: importLots,
        closures: periodClosures,
      );
      final activePeriodLabel = HumanResourcesPeriodContext.resolveSelected(
        selectedLabel: selectedPeriodLabel,
        availableLabels: periodOptions,
      );
      final rows = _buildNominaRows(
        draftRows: draftRows,
        activePeriodLabel: activePeriodLabel,
        personalFiscalModes: fiscalModes,
        isPeriodClosed: periodClosures.any(
          (p) => p.periodLabel == activePeriodLabel && p.isClosed,
        ),
      );

      _allRows = rows;
      _draftRows = draftRows;
      _periodClosures = periodClosures;
      _periodOptions = periodOptions;
      _activePeriodLabel = activePeriodLabel;
      _currentPage = 0;
      _rebuildVisibleRows();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allRows = const <_HrNominaSummaryRow>[];
        _visibleRows = const <_HrNominaSummaryRow>[];
        _activePeriodLabel = '';
        _selectedRowId = null;
        _loading = false;
      });
    }
  }

  Future<void> _selectPeriod(String periodLabel) async {
    await HumanResourcesPeriodContext.select(periodLabel);
    if (!mounted) return;
    await _loadData();
  }

  void _rebuildVisibleRows() {
    final pageCount = _filteredRows.isEmpty
        ? 1
        : ((_filteredRows.length - 1) ~/ _pageSize) + 1;
    _currentPage = _currentPage.clamp(0, pageCount - 1);
    final start = (_currentPage * _pageSize).clamp(0, _filteredRows.length);
    final end = (start + _pageSize).clamp(0, _filteredRows.length);
    _visibleRows = _filteredRows.sublist(start, end);
    if (_visibleRows.isEmpty) {
      _selectedRowId = null;
    } else if (!_visibleRows.any((row) => row.employeeId == _selectedRowId)) {
      _selectedRowId = _visibleRows.first.employeeId;
    }
    setState(() => _loading = false);
  }

  void _previousPage() {
    if (_currentPage <= 0) return;
    _currentPage -= 1;
    _rebuildVisibleRows();
  }

  void _nextPage() {
    final totalPages = _filteredRows.isEmpty
        ? 1
        : ((_filteredRows.length - 1) ~/ _pageSize) + 1;
    if (_currentPage >= totalPages - 1) return;
    _currentPage += 1;
    _rebuildVisibleRows();
  }

  void _changePageSize(int value) {
    _pageSize = value;
    _currentPage = 0;
    _rebuildVisibleRows();
  }

  Future<void> _openTerminations() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const HumanResourcesTerminationsPage(instantOpen: true),
      ),
    );
  }

  Future<void> _openLoans() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesLoansPage(instantOpen: true)),
    );
  }

  Future<void> _openDashboard() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openPersonnel() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesPersonnelPage(instantOpen: true)),
    );
  }

  Future<void> _openAttendance() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesAttendancePage(instantOpen: true)),
    );
  }

  Future<void> _openImportConciliation() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const HumanResourcesAttendanceIncidentsPage(instantOpen: true),
      ),
    );
  }

  Future<void> _openVacations() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesVacationsPage(instantOpen: true)),
    );
  }

  Future<void> _openPermissions() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const HumanResourcesPermissionsPage(instantOpen: true),
      ),
    );
  }

  Future<void> _openPrenomina() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const HumanResourcesPrenominaPage(instantOpen: true)),
    );
  }

  Future<void> _openDirectionDashboard() async {
    await Navigator.of(
      context,
    ).pushReplacement(appPageRoute(page: const GeneralDashboardPage()));
  }

  Future<void> _logout() async => signOutAndRouteToLogin(context);

  void _openRowDetail(_HrNominaSummaryRow row) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _HrNominaDetailDialog(
        row: row,
        activePeriodLabel: _activePeriodLabel,
        canGenerateReceipt: _isActivePeriodClosed,
        onGenerateReceipt: _generatePayrollReceipt,
        draft: _draftRows.where((draft) => draft.id == row.draftId).firstOrNull,
        onExportPeriodReport: _exportPeriodPayrollReportPdf,
        onOpenPrenomina: () async {
          Navigator.of(context).pop();
          await _openPrenomina();
        },
      ),
    );
  }

  Future<void> _generatePayrollReceipt(_HrNominaSummaryRow row) async {
    if (!_isActivePeriodClosed) {
      _showSnack(
        'Cierra el periodo completo en Prenómina antes de emitir recibos.',
      );
      return;
    }
    if (!row.isPublished || _activePeriodLabel.trim().isEmpty) {
      _showSnack('Publica la fila de Prenómina antes de emitir el recibo.');
      return;
    }
    _HrNominaDraftRecord? draft;
    for (final item in _draftRows) {
      if (item.employeeId == row.employeeId &&
          item.periodLabel == _activePeriodLabel) {
        draft = item;
        break;
      }
    }
    if (draft == null || draft.id.isEmpty) {
      _showSnack('No se encontró el cierre publicado para este colaborador.');
      return;
    }

    final existingSnapshot = _HrNominaReceiptSnapshot.tryFromJson(
      draft.sourceSnapshot['payroll_receipt'],
    );
    final snapshot =
        existingSnapshot ??
        _HrNominaReceiptSnapshot.fromSummaryRow(
          row: row,
          periodLabel: _activePeriodLabel,
          issuedAt: DateTime.now(),
          version: 1,
        );
    final client = Supabase.instance.client;
    Uint8List bytes;
    if (existingSnapshot == null) {
      bytes = await _buildHrNominaReceiptPdf(snapshot);
      final storagePath = _hrNominaReceiptStoragePath(snapshot);
      await client.storage
          .from(_kHrNominaReceiptBucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: false,
            ),
          );
      final sourceSnapshot = <String, dynamic>{
        ...draft.sourceSnapshot,
        'payroll_receipt': snapshot.toJson(),
        'payroll_receipt_storage_path': storagePath,
      };
      try {
        await client
            .from(_kHrNominaReceiptDocumentsTable)
            .insert(<String, dynamic>{
              'prenomina_draft_row_id': draft.id,
              'period_closure_id': _activePeriodClosure?.id,
              'employee_id': row.employeeId,
              'receipt_type': 'nomina',
              'version': snapshot.version,
              'storage_bucket': _kHrNominaReceiptBucket,
              'storage_path': storagePath,
              'file_size_bytes': bytes.length,
              'emitted_at': snapshot.issuedAt.toIso8601String(),
              'snapshot': snapshot.toJson(),
            });
        await client
            .from(_kHrNominaDraftRowsTable)
            .update(<String, dynamic>{'source_snapshot': sourceSnapshot})
            .eq('id', draft.id);
        await _loadData();
      } catch (_) {
        // El archivo permanece privado y no se considera emitido sin su
        // registro en base de datos. La limpieza requiere un ajuste auditado.
        rethrow;
      }
    } else {
      final storagePath =
          (draft.sourceSnapshot['payroll_receipt_storage_path'] ?? '')
              .toString();
      bytes = storagePath.isEmpty
          ? await _buildHrNominaReceiptPdf(snapshot)
          : await client.storage
                .from(_kHrNominaReceiptBucket)
                .download(storagePath);
    }

    final file = File(
      '${Directory.systemTemp.path}/recibo_nomina_${_hrNominaFileSlug(snapshot.employeeName)}_${snapshot.issuedAt.millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    await _openHrNominaReceiptPdf(file.path);
    if (!mounted) return;
    _showSnack(
      existingSnapshot == null
          ? 'Recibo v${snapshot.version} emitido y congelado para ${snapshot.employeeName}.'
          : 'Se abrió el recibo v${snapshot.version} ya emitido de ${snapshot.employeeName}.',
    );
  }

  Future<void> _exportPeriodPayrollReportPdf() async {
    if (_activePeriodLabel.trim().isEmpty || _allRows.isEmpty) {
      _showSnack('No hay una nómina de periodo para exportar.');
      return;
    }
    final bytes = await _buildHrNominaPeriodReportPdf(
      rows: _allRows,
      metrics: _HrNominaMetrics.fromRows(_allRows),
      periodLabel: _activePeriodLabel,
      generatedAt: DateTime.now(),
      isPeriodClosed: _isActivePeriodClosed,
    );
    final path = await saveBytesAs(
      bytes: bytes,
      suggestedFileName: 'nomina_${_hrNominaFileSlug(_activePeriodLabel)}.pdf',
      dialogTitle: 'Guardar desglose de nómina',
    );
    if (!mounted || path == null) return;
    _showSnack('Desglose de nómina del periodo exportado en PDF.');
  }

  Future<void> _openHrNominaReceiptPdf(String path) async {
    ProcessResult result;
    if (Platform.isMacOS) {
      result = await Process.run('open', <String>[path]);
    } else if (Platform.isWindows) {
      result = await Process.run('cmd', <String>['/c', 'start', '', path]);
    } else if (Platform.isLinux) {
      result = await Process.run('xdg-open', <String>[path]);
    } else {
      throw UnsupportedError('Plataforma no soportada para abrir PDF');
    }
    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString().trim());
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final visibleSelectionCount = _selectedRowId == null ? 0 : 1;
    final metrics = _HrNominaMetrics.fromRows(_allRows);
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
        centerBuilder: (_, _) => const _HrNominaHeaderBrand(),
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
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : _HrNominaWorkspace(
                          rows: _visibleRows,
                          periodRows: _allRows,
                          draftRows: _draftRows,
                          filters: _HrNominaFilters(
                            rows: _allRows,
                            controller: _searchController,
                            statuses: _statusFilters,
                            company: _companyFilter,
                            onSearch: (_) => _applyFilters(),
                            onStatus: (value) {
                              if (value == null) {
                                _statusFilters.clear();
                              } else if (!_statusFilters.remove(value)) {
                                _statusFilters.add(value);
                              }
                              _applyFilters();
                            },
                            onCompany: (value) {
                              _companyFilter = value;
                              _applyFilters();
                            },
                            onClear: () {
                              _searchController.clear();
                              _statusFilters.clear();
                              _companyFilter = null;
                              _applyFilters();
                            },
                          ),
                          totalRows: _filteredRows.length,
                          selectedCount: visibleSelectionCount,
                          activePeriodLabel: _activePeriodLabel,
                          periodOptions: _periodOptions,
                          isPeriodClosed: _isActivePeriodClosed,
                          metrics: metrics,
                          selectedRowId: _selectedRowId,
                          currentPage: _currentPage,
                          totalPages: _filteredRows.isEmpty
                              ? 1
                              : ((_filteredRows.length - 1) ~/ _pageSize) + 1,
                          pageSize: _pageSize,
                          onPreviousPage: _currentPage == 0
                              ? null
                              : _previousPage,
                          onNextPage:
                              (((_filteredRows.isEmpty
                                          ? 1
                                          : ((_filteredRows.length - 1) ~/
                                                    _pageSize) +
                                                1) -
                                      1) <=
                                  _currentPage)
                              ? null
                              : _nextPage,
                          onPageSizeChanged: _changePageSize,
                          onOpenPrenomina: _openPrenomina,
                          onExportPeriodReport: _exportPeriodPayrollReportPdf,
                          onSelectPeriod: _selectPeriod,
                          onSelectRow: (row) {
                            setState(() => _selectedRowId = row.employeeId);
                          },
                          onOpenRow: _openRowDetail,
                        ),
                ),
              ),
            ),
            HumanResourcesAreaNavigationOverlay(
              menuOpen: _menuOpen,
              onDismiss: () => setState(() => _menuOpen = false),
              canReturnToDirection: _canReturnToDirection,
              sections: buildHumanResourcesAreaSections(
                activeScreen: HumanResourcesAreaScreen.nomina,
                openPersonnel: _openPersonnel,
                openAttendance: _openAttendance,
                openImportConciliation: _openImportConciliation,
                openVacations: _openVacations,
                openPermissions: _openPermissions,
                openPrenomina: _openPrenomina,
                openNomina: () async {},
                openTerminations: _openTerminations,
                openLoans: _openLoans,
              ),
              accessItems: buildHumanResourcesAccessItems(
                activeScreen: HumanResourcesAreaScreen.nomina,
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

class _HrNominaStatusBadge extends StatelessWidget {
  final String label;

  const _HrNominaStatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = humanResourcesPayrollStatusColors(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: colors.foreground,
        ),
      ),
    );
  }
}

class _HrNominaGridFooter extends StatelessWidget {
  final int rows;
  final int totalRows;
  final int selectedCount;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<int> onPageSizeChanged;

  const _HrNominaGridFooter({
    required this.rows,
    required this.totalRows,
    required this.selectedCount,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        elevation: 0,
        color: humanResourcesAreaTokens.primarySoft.withValues(alpha: 0.56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                style: _hrNominaActionOutlinedButtonStyle(context),
                onPressed: onPreviousPage,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Anterior'),
              ),
              Text('Página ${currentPage + 1} de $totalPages'),
              OutlinedButton.icon(
                style: _hrNominaActionOutlinedButtonStyle(context),
                onPressed: onNextPage,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Siguiente'),
              ),
              const Text('Filas/pág:'),
              SizedBox(
                width: 90,
                child: DropdownButtonFormField<int>(
                  initialValue: pageSize,
                  isExpanded: true,
                  isDense: true,
                  decoration: _hrNominaFieldDecoration(),
                  items: const [40, 80, 120]
                      .map(
                        (e) =>
                            DropdownMenuItem<int>(value: e, child: Text('$e')),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onPageSizeChanged(value);
                  },
                ),
              ),
              Text(
                'Mostrando ${totalRows == 0 ? 0 : currentPage * pageSize + 1}–${currentPage * pageSize + rows} de $totalRows',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HrNominaHeaderBrand extends StatelessWidget {
  const _HrNominaHeaderBrand();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ContractGlassCard(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: const DicsaLogoD(size: 36, progress: 1),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recursos Humanos',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Nómina',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: humanResourcesAreaTokens.badgeText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HrNominaDetailBlock extends StatelessWidget {
  final String title;
  final List<_HrNominaDetailLine> rows;

  const _HrNominaDetailBlock({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: humanResourcesAreaTokens.primarySoft.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: humanResourcesAreaTokens.border.withValues(alpha: .25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: humanResourcesAreaTokens.badgeText,
              ),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < rows.length; index++) ...[
              rows[index],
              if (index != rows.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _HrNominaDetailLine extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _HrNominaDetailLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w400,
              color: humanResourcesAreaTokens.onGlass,
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: emphasized ? FontWeight.w900 : FontWeight.w600,
              color: humanResourcesAreaTokens.onGlass,
            ),
          ),
        ),
      ],
    );
  }
}

class _HrNominaSideData extends StatelessWidget {
  final String label;
  final String value;

  const _HrNominaSideData({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: humanResourcesAreaTokens.badgeText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: humanResourcesAreaTokens.onGlass,
            ),
          ),
        ],
      ),
    );
  }
}

class _HrNominaImportLotLite {
  final String periodLabel;
  final String source;
  final DateTime? importedAt;

  const _HrNominaImportLotLite({
    required this.periodLabel,
    required this.source,
    required this.importedAt,
  });

  factory _HrNominaImportLotLite.fromRow(Map<String, dynamic> row) {
    return _HrNominaImportLotLite(
      periodLabel: (row['period_label'] ?? '').toString(),
      source: (row['source'] ?? '').toString(),
      importedAt: _parseHrNominaDate(row['imported_at']),
    );
  }
}

class _HrNominaPeriodClosure {
  final String id;
  final String periodLabel;
  final String status;

  const _HrNominaPeriodClosure({
    required this.id,
    required this.periodLabel,
    required this.status,
  });

  bool get isClosed => status == 'cerrado';

  factory _HrNominaPeriodClosure.fromRow(Map<String, dynamic> row) {
    return _HrNominaPeriodClosure(
      id: (row['id'] ?? '').toString(),
      periodLabel: (row['period_label'] ?? '').toString(),
      status: (row['status'] ?? '').toString(),
    );
  }
}

class _HrNominaDraftRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final String empresa;
  final String periodLabel;
  final DateTime? createdAt;
  final String draftStatus;
  final double manualAdjustmentAmount;
  final double fiscalNetAmount;
  final double fiscalLateDeductionAmount;
  final double fiscalManualDeductionAmount;
  final String fiscalManualDeductionReason;
  final double cashSalaryAmount;
  final double cashVacationAmount;
  final double cashIsrAmount;
  final double transportSupportAmount;
  final double holidayAmount;
  final double overtimeMonetizedAmount;
  final double manualBonusAmount;
  final double cashAbsenceDeductionAmount;
  final double cashInfonavitDeductionAmount;
  final double cashFonacotDeductionAmount;
  final double loanDeductionAmount;
  final double checkAmount;
  final double paymentOutsideAmount;
  final String paymentChannel;
  final String paymentReference;
  final String notes;
  final Map<String, dynamic> sourceSnapshot;

  const _HrNominaDraftRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.empresa,
    required this.periodLabel,
    required this.createdAt,
    required this.draftStatus,
    required this.manualAdjustmentAmount,
    required this.fiscalNetAmount,
    required this.fiscalLateDeductionAmount,
    this.fiscalManualDeductionAmount = 0,
    this.fiscalManualDeductionReason = '',
    required this.cashSalaryAmount,
    required this.cashVacationAmount,
    required this.cashIsrAmount,
    required this.transportSupportAmount,
    required this.holidayAmount,
    required this.overtimeMonetizedAmount,
    required this.manualBonusAmount,
    required this.cashAbsenceDeductionAmount,
    required this.cashInfonavitDeductionAmount,
    required this.cashFonacotDeductionAmount,
    required this.loanDeductionAmount,
    required this.checkAmount,
    required this.paymentOutsideAmount,
    required this.paymentChannel,
    required this.paymentReference,
    required this.notes,
    required this.sourceSnapshot,
  });

  factory _HrNominaDraftRecord.fromRow(Map<String, dynamic> row) {
    return _HrNominaDraftRecord(
      id: (row['id'] ?? '').toString(),
      employeeId: (row['employee_id'] ?? '').toString(),
      employeeName: (row['employee_name'] ?? '').toString(),
      empresa: (row['empresa'] ?? '').toString(),
      periodLabel: (row['period_label'] ?? '').toString(),
      createdAt: _parseHrNominaDate(row['created_at']),
      draftStatus: (row['draft_status'] ?? '').toString(),
      manualAdjustmentAmount: _parseHrNominaNumber(
        row['manual_adjustment_amount'],
      ),
      fiscalNetAmount: _parseHrNominaNumber(row['fiscal_net_amount']),
      fiscalManualDeductionAmount: _parseHrNominaNumber(
        row['fiscal_manual_deduction_amount'],
      ),
      fiscalManualDeductionReason: (row['fiscal_manual_deduction_reason'] ?? '')
          .toString(),
      fiscalLateDeductionAmount: _parseHrNominaNumber(
        row['fiscal_late_deduction_amount'],
      ),
      cashSalaryAmount: _parseHrNominaNumber(row['cash_salary_amount']),
      cashVacationAmount: _parseHrNominaNumber(row['cash_vacation_amount']),
      cashIsrAmount: _parseHrNominaNumber(row['cash_isr_amount']),
      transportSupportAmount: _parseHrNominaNumber(
        row['transport_support_amount'],
      ),
      holidayAmount: _parseHrNominaNumber(row['holiday_amount']),
      overtimeMonetizedAmount: _parseHrNominaNumber(
        row['overtime_monetized_amount'],
      ),
      manualBonusAmount: _parseHrNominaNumber(row['manual_bonus_amount']),
      cashAbsenceDeductionAmount: _parseHrNominaNumber(
        row['cash_absence_deduction_amount'],
      ),
      cashInfonavitDeductionAmount: _parseHrNominaNumber(
        row['cash_infonavit_deduction_amount'],
      ),
      cashFonacotDeductionAmount: _parseHrNominaNumber(
        row['cash_fonacot_deduction_amount'],
      ),
      loanDeductionAmount: _parseHrNominaNumber(row['loan_deduction_amount']),
      checkAmount: _parseHrNominaNumber(row['check_amount']),
      paymentOutsideAmount: _parseHrNominaNumber(row['payment_outside_amount']),
      paymentChannel: (row['payment_channel'] ?? '').toString(),
      paymentReference: (row['payment_reference'] ?? '').toString(),
      notes: (row['notes'] ?? '').toString(),
      sourceSnapshot: Map<String, dynamic>.from(
        (row['source_snapshot'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }
}

class _HrNominaSummaryRow {
  final bool incidencesInformational;
  final String draftId;
  final String draftStatus;
  final String employeeId;
  final String employeeName;
  final String empresa;
  final String statusLabel;
  final String paymentChannelLabel;
  final String paymentReference;
  final String notes;
  final double fiscalAmount;
  final double fiscalLateDeductionAmount;
  final double fiscalManualDeductionAmount;
  final String fiscalManualDeductionReason;
  final double complementsAmount;
  final double deductionsAmount;
  final double totalAmount;
  final double manualAdjustmentAmount;
  final double cashSalaryAmount;
  final double cashVacationAmount;
  final double cashIsrAmount;
  final double transportSupportAmount;
  final double holidayAmount;
  final double overtimeMonetizedAmount;
  final double manualBonusAmount;
  final double cashAbsenceDeductionAmount;
  final double cashInfonavitDeductionAmount;
  final double cashFonacotDeductionAmount;
  final double loanDeductionAmount;
  final double checkAmount;
  final double paymentOutsideAmount;

  const _HrNominaSummaryRow({
    this.incidencesInformational = false,
    required this.draftId,
    required this.draftStatus,
    required this.employeeId,
    required this.employeeName,
    required this.empresa,
    required this.statusLabel,
    required this.paymentChannelLabel,
    required this.paymentReference,
    required this.notes,
    required this.fiscalAmount,
    required this.fiscalLateDeductionAmount,
    this.fiscalManualDeductionAmount = 0,
    this.fiscalManualDeductionReason = '',
    required this.complementsAmount,
    required this.deductionsAmount,
    required this.totalAmount,
    required this.manualAdjustmentAmount,
    required this.cashSalaryAmount,
    required this.cashVacationAmount,
    required this.cashIsrAmount,
    required this.transportSupportAmount,
    required this.holidayAmount,
    required this.overtimeMonetizedAmount,
    required this.manualBonusAmount,
    required this.cashAbsenceDeductionAmount,
    required this.cashInfonavitDeductionAmount,
    required this.cashFonacotDeductionAmount,
    required this.loanDeductionAmount,
    required this.checkAmount,
    required this.paymentOutsideAmount,
  });

  double get fiscalCashAmount =>
      checkAmount.clamp(0, fiscalAmount.clamp(0, double.infinity));
  String get fiscalDeliveryLabel => fiscalCashAmount > 0
      ? (fiscalDepositedAmount > 0 ? 'Depósito + cheque' : 'Cheque · efectivo')
      : 'Depósito';

  bool get isPublished => draftStatus == 'publicado';

  double get fiscalDepositedAmount {
    final amount = fiscalAmount - fiscalCashAmount;
    return amount < 0 ? 0 : amount;
  }

  double get operationalCashAmount => complementsAmount - deductionsAmount;
  double get flowDeliveryAmount => totalAmount - fiscalDepositedAmount;
}

class _HrNominaMetrics {
  final int rows;
  final double fiscal;
  final double fiscalDeposited;
  final double fiscalCash;
  final double operationalCash;
  final double complements;
  final double deductions;
  final double checks;
  final double outside;
  final double total;

  const _HrNominaMetrics({
    required this.rows,
    required this.fiscal,
    required this.fiscalDeposited,
    required this.fiscalCash,
    required this.operationalCash,
    required this.complements,
    required this.deductions,
    required this.checks,
    required this.outside,
    required this.total,
  });

  factory _HrNominaMetrics.fromRows(List<_HrNominaSummaryRow> rows) {
    var fiscal = 0.0;
    var fiscalDeposited = 0.0;
    var fiscalCash = 0.0;
    var operationalCash = 0.0;
    var complements = 0.0;
    var deductions = 0.0;
    var checks = 0.0;
    var outside = 0.0;
    var total = 0.0;
    for (final row in rows) {
      fiscal += row.fiscalAmount;
      fiscalDeposited += row.fiscalDepositedAmount;
      fiscalCash += row.fiscalCashAmount;
      operationalCash += row.operationalCashAmount;
      complements += row.complementsAmount;
      deductions += row.deductionsAmount;
      checks += row.fiscalCashAmount;
      outside += row.paymentOutsideAmount;
      total += row.totalAmount;
    }
    return _HrNominaMetrics(
      rows: rows.length,
      fiscal: fiscal,
      fiscalDeposited: fiscalDeposited,
      fiscalCash: fiscalCash,
      operationalCash: operationalCash,
      complements: complements,
      deductions: deductions,
      checks: checks,
      outside: outside,
      total: total,
    );
  }
}

List<String> _nominaPeriodOptions({
  required List<_HrNominaDraftRecord> drafts,
  required List<_HrNominaImportLotLite> lots,
  required List<_HrNominaPeriodClosure> closures,
}) {
  return HumanResourcesPeriodContext.normalizedOptions([
    for (final draft in drafts) draft.periodLabel,
    for (final closure in closures) closure.periodLabel,
  ]);
}

List<_HrNominaSummaryRow> _buildNominaRows({
  required List<_HrNominaDraftRecord> draftRows,
  required String activePeriodLabel,
  Map<String, String> personalFiscalModes = const {},
  bool isPeriodClosed = false,
}) {
  if (activePeriodLabel.isEmpty) return const <_HrNominaSummaryRow>[];
  final sourceRows = draftRows
      .where((row) => row.periodLabel == activePeriodLabel)
      .toList(growable: false);
  final rows = sourceRows
      .map((draft) {
        final complements =
            draft.cashSalaryAmount +
            draft.cashVacationAmount +
            draft.transportSupportAmount +
            draft.holidayAmount +
            draft.overtimeMonetizedAmount +
            draft.manualBonusAmount +
            draft.manualAdjustmentAmount;
        final deductions =
            draft.cashIsrAmount +
            (draft.sourceSnapshot['incidences_informational'] == true
                ? 0
                : draft.cashAbsenceDeductionAmount) +
            draft.cashInfonavitDeductionAmount +
            draft.cashFonacotDeductionAmount +
            draft.loanDeductionAmount;
        final fiscalAmount =
            (draft.fiscalNetAmount -
                    draft.fiscalManualDeductionAmount -
                    (draft.sourceSnapshot['incidences_informational'] == true
                        ? 0
                        : draft.fiscalLateDeductionAmount))
                .clamp(0, double.infinity)
                .toDouble();
        final frozenDelivery =
            isPeriodClosed ||
            draft.draftStatus == 'publicado' ||
            draft.sourceSnapshot['payroll_receipt'] is Map;
        final payment = HrFiscalPayment.resolve(
          total: fiscalAmount,
          storedCheque: draft.checkAmount,
          snapshot: draft.sourceSnapshot,
          personalMode: personalFiscalModes[draft.employeeId],
          frozen: frozenDelivery,
        );
        final usesPersonalMode =
            !frozenDelivery &&
            !HrFiscalPayment.isManual(
              draft.sourceSnapshot,
              draft.checkAmount,
            ) &&
            (personalFiscalModes.containsKey(draft.employeeId) ||
                draft.sourceSnapshot['personal_fiscal_payment_mode'] != null);
        final deliveryChannel = payment.cheque > 0
            ? (payment.deposit > 0 ||
                      complements - deductions > 0 ||
                      draft.paymentOutsideAmount > 0
                  ? 'mixto'
                  : 'cheque')
            : (payment.total > 0
                  ? (complements - deductions > 0 ||
                            draft.paymentOutsideAmount > 0
                        ? 'mixto'
                        : 'deposito')
                  : (complements - deductions > 0 ? 'efectivo' : 'pendiente'));
        final total =
            fiscalAmount +
            draft.paymentOutsideAmount +
            complements -
            deductions;
        return _HrNominaSummaryRow(
          incidencesInformational:
              draft.sourceSnapshot['incidences_informational'] == true,
          draftId: draft.id,
          draftStatus: draft.draftStatus,
          employeeId: draft.employeeId,
          employeeName: draft.employeeName,
          empresa: draft.empresa,
          statusLabel: _hrNominaDraftStatusLabel(draft.draftStatus),
          paymentChannelLabel: _hrNominaPaymentChannelLabel(
            usesPersonalMode ? deliveryChannel : draft.paymentChannel,
          ),
          paymentReference: draft.paymentReference,
          notes: draft.notes,
          fiscalAmount: fiscalAmount,
          fiscalLateDeductionAmount: draft.fiscalLateDeductionAmount,
          fiscalManualDeductionAmount: draft.fiscalManualDeductionAmount,
          fiscalManualDeductionReason: draft.fiscalManualDeductionReason,
          complementsAmount: complements,
          deductionsAmount: deductions,
          totalAmount: total,
          manualAdjustmentAmount: draft.manualAdjustmentAmount,
          cashSalaryAmount: draft.cashSalaryAmount,
          cashVacationAmount: draft.cashVacationAmount,
          cashIsrAmount: draft.cashIsrAmount,
          transportSupportAmount: draft.transportSupportAmount,
          holidayAmount: draft.holidayAmount,
          overtimeMonetizedAmount: draft.overtimeMonetizedAmount,
          manualBonusAmount: draft.manualBonusAmount,
          cashAbsenceDeductionAmount: draft.cashAbsenceDeductionAmount,
          cashInfonavitDeductionAmount: draft.cashInfonavitDeductionAmount,
          cashFonacotDeductionAmount: draft.cashFonacotDeductionAmount,
          loanDeductionAmount: draft.loanDeductionAmount,
          checkAmount: payment.cheque,
          paymentOutsideAmount: draft.paymentOutsideAmount,
        );
      })
      .toList(growable: false);
  rows.sort((a, b) => _compareEmployeeIds(a.employeeId, b.employeeId));
  return rows;
}

int _compareEmployeeIds(String a, String b) {
  final int? aInt = int.tryParse(a);
  final int? bInt = int.tryParse(b);
  if (aInt != null && bInt != null) return aInt.compareTo(bInt);
  return a.compareTo(b);
}

String _hrNominaDraftStatusLabel(String value) {
  switch (value) {
    case 'revisionRh':
      return 'Revisión RH';
    case 'listo':
      return 'Listo';
    case 'publicado':
      return 'Publicado';
    default:
      return 'Borrador';
  }
}

String _hrNominaPaymentChannelLabel(String value) {
  switch (value) {
    case 'deposito':
      return 'Depósito fiscal';
    case 'cheque':
      return 'Fiscal en efectivo';
    case 'mixto':
      return 'Mixto';
    case 'efectivo':
      return 'Efectivo';
    case 'pagoFuera':
      return 'Pago por fuera';
    default:
      return 'Pendiente';
  }
}

DateTime? _parseHrNominaDate(Object? raw) {
  final text = raw?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}

double _parseHrNominaNumber(Object? raw) {
  final text = raw?.toString().trim();
  if (text == null || text.isEmpty) return 0;
  return double.tryParse(text) ?? 0;
}

String _fmtHrNominaMoney(double value) {
  final negative = value < 0;
  final absValue = value.abs();
  final parts = absValue.toStringAsFixed(2).split('.');
  final whole = parts.first;
  final decimal = parts.last;
  final buffer = StringBuffer();
  for (var index = 0; index < whole.length; index++) {
    final reverseIndex = whole.length - index;
    buffer.write(whole[index]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  final sign = negative ? '-' : '';
  return '$sign\$$buffer.$decimal';
}

ButtonStyle _hrNominaActionOutlinedButtonStyle(BuildContext context) {
  return _nominaOutlinedStyle(context);
}

InputDecoration _hrNominaFieldDecoration() {
  return InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    filled: true,
    fillColor: humanResourcesAreaTokens.onGlass.withValues(alpha: .8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: humanResourcesAreaTokens.border.withValues(alpha: .45),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: humanResourcesAreaTokens.border.withValues(alpha: .45),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: humanResourcesAreaTokens.border,
        width: 1.6,
      ),
    ),
  );
}

class _HrNominaReceiptSnapshot {
  final bool incidencesInformational;
  final String employeeId;
  final String employeeName;
  final String empresa;
  final String periodLabel;
  final DateTime issuedAt;
  final int version;
  final String paymentChannel;
  final String paymentReference;
  final String notes;
  final double fiscalAmount;
  final double fiscalLateDeductionAmount;
  final double fiscalManualDeductionAmount;
  final String fiscalManualDeductionReason;
  final double fiscalDepositedAmount;
  final double fiscalCashAmount;
  final double cashSalaryAmount;
  final double cashVacationAmount;
  final double transportSupportAmount;
  final double holidayAmount;
  final double overtimeAmount;
  final double manualBonusAmount;
  final double manualAdjustmentAmount;
  final double cashIsrAmount;
  final double absenceDeductionAmount;
  final double infonavitDeductionAmount;
  final double fonacotDeductionAmount;
  final double loanDeductionAmount;
  final double paymentOutsideAmount;
  final double totalAmount;

  const _HrNominaReceiptSnapshot({
    this.incidencesInformational = false,
    required this.employeeId,
    required this.employeeName,
    required this.empresa,
    required this.periodLabel,
    required this.issuedAt,
    required this.version,
    required this.paymentChannel,
    required this.paymentReference,
    required this.notes,
    required this.fiscalAmount,
    required this.fiscalLateDeductionAmount,
    this.fiscalManualDeductionAmount = 0,
    this.fiscalManualDeductionReason = '',
    required this.fiscalDepositedAmount,
    required this.fiscalCashAmount,
    required this.cashSalaryAmount,
    required this.cashVacationAmount,
    required this.transportSupportAmount,
    required this.holidayAmount,
    required this.overtimeAmount,
    required this.manualBonusAmount,
    required this.manualAdjustmentAmount,
    required this.cashIsrAmount,
    required this.absenceDeductionAmount,
    required this.infonavitDeductionAmount,
    required this.fonacotDeductionAmount,
    required this.loanDeductionAmount,
    required this.paymentOutsideAmount,
    required this.totalAmount,
  });

  factory _HrNominaReceiptSnapshot.fromSummaryRow({
    required _HrNominaSummaryRow row,
    required String periodLabel,
    required DateTime issuedAt,
    required int version,
  }) {
    return _HrNominaReceiptSnapshot(
      employeeId: row.employeeId,
      employeeName: row.employeeName,
      empresa: row.empresa,
      periodLabel: periodLabel,
      issuedAt: issuedAt,
      version: version,
      paymentChannel: row.paymentChannelLabel,
      paymentReference: row.paymentReference,
      notes: row.notes,
      fiscalAmount: row.fiscalAmount,
      incidencesInformational: row.incidencesInformational,
      fiscalLateDeductionAmount: row.fiscalLateDeductionAmount,
      fiscalManualDeductionAmount: row.fiscalManualDeductionAmount,
      fiscalManualDeductionReason: row.fiscalManualDeductionReason,
      fiscalDepositedAmount: row.fiscalDepositedAmount,
      fiscalCashAmount: row.fiscalCashAmount,
      cashSalaryAmount: row.cashSalaryAmount,
      cashVacationAmount: row.cashVacationAmount,
      transportSupportAmount: row.transportSupportAmount,
      holidayAmount: row.holidayAmount,
      overtimeAmount: row.overtimeMonetizedAmount,
      manualBonusAmount: row.manualBonusAmount,
      manualAdjustmentAmount: row.manualAdjustmentAmount,
      cashIsrAmount: row.cashIsrAmount,
      absenceDeductionAmount: row.cashAbsenceDeductionAmount,
      infonavitDeductionAmount: row.cashInfonavitDeductionAmount,
      fonacotDeductionAmount: row.cashFonacotDeductionAmount,
      loanDeductionAmount: row.loanDeductionAmount,
      paymentOutsideAmount: row.paymentOutsideAmount,
      totalAmount: row.totalAmount,
    );
  }

  static _HrNominaReceiptSnapshot? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final value = Map<String, dynamic>.from(raw);
    final issuedAt = _parseHrNominaDate(value['issued_at']);
    if (issuedAt == null || (value['employee_id'] ?? '').toString().isEmpty) {
      return null;
    }
    return _HrNominaReceiptSnapshot(
      employeeId: (value['employee_id'] ?? '').toString(),
      employeeName: (value['employee_name'] ?? '').toString(),
      empresa: (value['empresa'] ?? '').toString(),
      periodLabel: (value['period_label'] ?? '').toString(),
      issuedAt: issuedAt,
      version: (value['version'] as num?)?.toInt() ?? 1,
      paymentChannel: (value['payment_channel'] ?? '').toString(),
      paymentReference: (value['payment_reference'] ?? '').toString(),
      notes: (value['notes'] ?? '').toString(),
      fiscalAmount: _parseHrNominaNumber(value['fiscal_amount']),
      fiscalManualDeductionAmount: _parseHrNominaNumber(
        value['fiscal_manual_deduction_amount'],
      ),
      fiscalManualDeductionReason:
          (value['fiscal_manual_deduction_reason'] ?? '').toString(),
      incidencesInformational: value['incidences_informational'] == true,
      fiscalLateDeductionAmount: _parseHrNominaNumber(
        value['fiscal_late_deduction_amount'],
      ),
      fiscalDepositedAmount: _parseHrNominaNumber(
        value['fiscal_deposited_amount'],
      ),
      fiscalCashAmount: _parseHrNominaNumber(value['fiscal_cash_amount']),
      cashSalaryAmount: _parseHrNominaNumber(value['cash_salary_amount']),
      cashVacationAmount: _parseHrNominaNumber(value['cash_vacation_amount']),
      transportSupportAmount: _parseHrNominaNumber(
        value['transport_support_amount'],
      ),
      holidayAmount: _parseHrNominaNumber(value['holiday_amount']),
      overtimeAmount: _parseHrNominaNumber(value['overtime_amount']),
      manualBonusAmount: _parseHrNominaNumber(value['manual_bonus_amount']),
      manualAdjustmentAmount: _parseHrNominaNumber(
        value['manual_adjustment_amount'],
      ),
      cashIsrAmount: _parseHrNominaNumber(value['cash_isr_amount']),
      absenceDeductionAmount: _parseHrNominaNumber(
        value['absence_deduction_amount'],
      ),
      infonavitDeductionAmount: _parseHrNominaNumber(
        value['infonavit_deduction_amount'],
      ),
      fonacotDeductionAmount: _parseHrNominaNumber(
        value['fonacot_deduction_amount'],
      ),
      loanDeductionAmount: _parseHrNominaNumber(value['loan_deduction_amount']),
      paymentOutsideAmount: _parseHrNominaNumber(
        value['payment_outside_amount'],
      ),
      totalAmount: _parseHrNominaNumber(value['total_amount']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'employee_id': employeeId,
    'employee_name': employeeName,
    'empresa': empresa,
    'period_label': periodLabel,
    'issued_at': issuedAt.toIso8601String(),
    'version': version,
    'payment_channel': paymentChannel,
    'payment_reference': paymentReference,
    'notes': notes,
    'fiscal_amount': fiscalAmount,
    'incidences_informational': incidencesInformational,
    'fiscal_late_deduction_amount': fiscalLateDeductionAmount,
    'fiscal_manual_deduction_amount': fiscalManualDeductionAmount,
    'fiscal_manual_deduction_reason': fiscalManualDeductionReason,
    'fiscal_deposited_amount': fiscalDepositedAmount,
    'fiscal_cash_amount': fiscalCashAmount,
    'cash_salary_amount': cashSalaryAmount,
    'cash_vacation_amount': cashVacationAmount,
    'transport_support_amount': transportSupportAmount,
    'holiday_amount': holidayAmount,
    'overtime_amount': overtimeAmount,
    'manual_bonus_amount': manualBonusAmount,
    'manual_adjustment_amount': manualAdjustmentAmount,
    'cash_isr_amount': cashIsrAmount,
    'absence_deduction_amount': absenceDeductionAmount,
    'infonavit_deduction_amount': infonavitDeductionAmount,
    'fonacot_deduction_amount': fonacotDeductionAmount,
    'loan_deduction_amount': loanDeductionAmount,
    'payment_outside_amount': paymentOutsideAmount,
    'total_amount': totalAmount,
  };

  double get complements =>
      cashSalaryAmount +
      cashVacationAmount +
      transportSupportAmount +
      holidayAmount +
      overtimeAmount +
      manualBonusAmount +
      manualAdjustmentAmount;

  double get deductions =>
      cashIsrAmount +
      (incidencesInformational ? 0 : absenceDeductionAmount) +
      infonavitDeductionAmount +
      fonacotDeductionAmount +
      loanDeductionAmount;
}

Future<Uint8List> _buildHrNominaReceiptPdf(
  _HrNominaReceiptSnapshot snapshot,
) async {
  final purple = PdfColor.fromHex('#3B1F5C');
  final violet = PdfColor.fromHex('#7C4DFF');
  final ink = PdfColor.fromHex('#24143D');
  final muted = PdfColor.fromHex('#6E5A8B');
  final border = PdfColor.fromHex('#D9C8F8');
  pw.MemoryImage? logo;
  try {
    final logoBytes = await rootBundle.load('assets/images/logo_dicsa.png');
    logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
  } catch (_) {
    // La información del recibo no depende de que el recurso visual exista.
  }

  final document = pw.Document(
    title: 'Recibo de nómina ${snapshot.employeeName}',
    author: 'DICSA - Recursos Humanos',
  );
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: purple,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              children: [
                if (logo != null)
                  pw.Container(
                    width: 46,
                    height: 46,
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                if (logo != null) pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DESPERDICIOS INDUSTRIALES CELAYA, S.A. DE C.V.',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'RECIBO DE NÓMINA',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 21,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Recursos Humanos · Versión ${snapshot.version}',
                        style: pw.TextStyle(
                          color: PdfColor.fromHex('#DCC7FF'),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                _hrNominaPdfMeta(
                  'EMISIÓN',
                  _hrNominaPdfDate(snapshot.issuedAt),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          _hrNominaPdfSection(
            title: 'Datos del colaborador',
            color: violet,
            child: pw.Column(
              children: [
                _hrNominaPdfData('Nombre', snapshot.employeeName),
                _hrNominaPdfData(
                  'ID / Empresa',
                  '#${snapshot.employeeId} · ${snapshot.empresa}',
                ),
                _hrNominaPdfData('Periodo de cierre', snapshot.periodLabel),
                _hrNominaPdfData('Canal de pago', snapshot.paymentChannel),
                if (snapshot.paymentReference.isNotEmpty)
                  _hrNominaPdfData('Referencia', snapshot.paymentReference),
                if (snapshot.fiscalManualDeductionAmount > 0)
                  _hrNominaPdfData(
                    'Motivo del descuento fiscal',
                    snapshot.fiscalManualDeductionReason,
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _hrNominaPdfSection(
                  title: 'Percepciones y pagos',
                  color: violet,
                  child: _hrNominaPdfTotals(
                    rows: [
                      (
                        snapshot.incidencesInformational
                            ? 'Neto fiscal oficial'
                            : 'Fiscal antes de retardo',
                        snapshot.fiscalAmount +
                            snapshot.fiscalManualDeductionAmount +
                            (snapshot.incidencesInformational
                                ? 0
                                : snapshot.fiscalLateDeductionAmount),
                      ),
                      ('Sueldo en efectivo', snapshot.cashSalaryAmount),
                      ('Vacaciones en efectivo', snapshot.cashVacationAmount),
                      ('Apoyo transporte', snapshot.transportSupportAmount),
                      ('Día festivo', snapshot.holidayAmount),
                      ('Horas extra', snapshot.overtimeAmount),
                      (
                        'Bono / ajuste RH',
                        snapshot.manualBonusAmount +
                            snapshot.manualAdjustmentAmount,
                      ),
                      ('Pago por fuera', snapshot.paymentOutsideAmount),
                    ],
                    totalLabel: 'TOTAL PERCEPCIONES',
                    total:
                        snapshot.fiscalAmount +
                        snapshot.fiscalManualDeductionAmount +
                        (snapshot.incidencesInformational
                            ? 0
                            : snapshot.fiscalLateDeductionAmount) +
                        snapshot.complements +
                        snapshot.paymentOutsideAmount,
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _hrNominaPdfSection(
                  title: 'Deducciones RH',
                  color: violet,
                  child: _hrNominaPdfTotals(
                    rows: [
                      (
                        snapshot.incidencesInformational
                            ? 'Retardos (informativo)'
                            : 'Retardos fiscales',
                        snapshot.fiscalLateDeductionAmount,
                      ),
                      if (snapshot.fiscalManualDeductionAmount > 0)
                        (
                          'Descuento fiscal manual',
                          snapshot.fiscalManualDeductionAmount,
                        ),
                      ('ISR operativo', snapshot.cashIsrAmount),
                      (
                        snapshot.incidencesInformational
                            ? 'Ausencias (informativo)'
                            : 'Ausencias',
                        snapshot.absenceDeductionAmount,
                      ),
                      ('INFONAVIT', snapshot.infonavitDeductionAmount),
                      ('FONACOT', snapshot.fonacotDeductionAmount),
                      ('Préstamo', snapshot.loanDeductionAmount),
                    ],
                    totalLabel: 'TOTAL DEDUCCIONES',
                    total:
                        (snapshot.incidencesInformational
                            ? 0
                            : snapshot.fiscalLateDeductionAmount) +
                        snapshot.deductions +
                        snapshot.fiscalManualDeductionAmount,
                    negativeRows: true,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          _hrNominaPdfSection(
            title: 'Forma de entrega',
            color: violet,
            child: pw.Column(
              children: [
                _hrNominaPdfData(
                  'Fiscal depositado',
                  _fmtHrNominaMoney(snapshot.fiscalDepositedAmount),
                ),
                _hrNominaPdfData(
                  'Fiscal en efectivo / cheque',
                  _fmtHrNominaMoney(snapshot.fiscalCashAmount),
                ),
                _hrNominaPdfData(
                  'Efectivo RH',
                  _fmtHrNominaMoney(snapshot.complements - snapshot.deductions),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: pw.BoxDecoration(
              color: purple,
              borderRadius: pw.BorderRadius.circular(9),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL DE PAGO',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                pw.Text(
                  _fmtHrNominaMoney(snapshot.totalAmount),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          if (snapshot.notes.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Observaciones RH: ${snapshot.notes}',
              style: pw.TextStyle(color: muted, fontSize: 8.5),
            ),
          ],
          pw.Spacer(),
          pw.Row(
            children: [
              _hrNominaPdfSignature(
                'Nombre y firma del trabajador',
                snapshot.employeeName,
                ink,
                border,
              ),
              pw.SizedBox(width: 32),
              _hrNominaPdfSignature('Recursos Humanos', 'DICSA', ink, border),
            ],
          ),
        ],
      ),
    ),
  );
  return document.save();
}

pw.Widget _hrNominaPdfSection({
  required String title,
  required PdfColor color,
  required pw.Widget child,
}) => pw.Container(
  padding: const pw.EdgeInsets.all(11),
  decoration: pw.BoxDecoration(
    color: PdfColors.white,
    border: pw.Border.all(color: PdfColor.fromHex('#D9C8F8')),
    borderRadius: pw.BorderRadius.circular(9),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(
          color: color,
          fontWeight: pw.FontWeight.bold,
          fontSize: 12,
        ),
      ),
      pw.SizedBox(height: 8),
      child,
    ],
  ),
);

pw.Widget _hrNominaPdfData(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 5),
  child: pw.Row(
    children: [
      pw.SizedBox(
        width: 125,
        child: pw.Text(
          label,
          style: pw.TextStyle(
            color: PdfColor.fromHex('#6E5A8B'),
            fontSize: 8.5,
          ),
        ),
      ),
      pw.Expanded(
        child: pw.Text(
          value,
          style: pw.TextStyle(
            color: PdfColor.fromHex('#24143D'),
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    ],
  ),
);

pw.Widget _hrNominaPdfTotals({
  required List<(String, double)> rows,
  required String totalLabel,
  required double total,
  bool negativeRows = false,
}) => pw.Column(
  children: [
    for (final row in rows)
      _hrNominaPdfData(
        row.$1,
        '${negativeRows && row.$2 > 0 ? '-' : ''}${_fmtHrNominaMoney(row.$2)}',
      ),
    pw.Divider(color: PdfColor.fromHex('#D9C8F8')),
    _hrNominaPdfData(totalLabel, _fmtHrNominaMoney(total)),
  ],
);

pw.Widget _hrNominaPdfMeta(String label, String value) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.end,
  children: [
    pw.Text(
      label,
      style: pw.TextStyle(color: PdfColor.fromHex('#DCC7FF'), fontSize: 7.5),
    ),
    pw.Text(
      value,
      style: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  ],
);

pw.Widget _hrNominaPdfSignature(
  String label,
  String name,
  PdfColor ink,
  PdfColor border,
) => pw.Expanded(
  child: pw.Column(
    children: [
      pw.Container(height: 1, color: border),
      pw.SizedBox(height: 5),
      pw.Text(
        label,
        style: pw.TextStyle(
          color: ink,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.Text(
        name,
        style: pw.TextStyle(color: PdfColor.fromHex('#6E5A8B'), fontSize: 7.5),
      ),
    ],
  ),
);

String _hrNominaPdfDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _hrNominaFileSlug(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

String _hrNominaReceiptStoragePath(_HrNominaReceiptSnapshot snapshot) {
  final period = _hrNominaFileSlug(snapshot.periodLabel);
  final employee = _hrNominaFileSlug(snapshot.employeeName);
  return 'periodos/$period/$snapshot.employeeId/$employee/recibo_v${snapshot.version}_${snapshot.issuedAt.millisecondsSinceEpoch}.pdf';
}
