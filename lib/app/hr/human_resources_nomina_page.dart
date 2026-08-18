import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/fetch_all_supabase_rows.dart';
import 'human_resources_area_chrome.dart';
import 'human_resources_attendance_incidents_page.dart';
import 'human_resources_attendance_page.dart';
import 'human_resources_dashboard_page.dart';
import 'human_resources_permissions_page.dart';
import 'human_resources_personnel_page.dart';
import 'human_resources_prenomina_page.dart';
import 'human_resources_theme.dart';
import 'human_resources_vacations_page.dart';

const String _kHrNominaDraftRowsTable = 'hr_prenomina_draft_rows';
const String _kHrNominaImportLotsTable = 'hr_attendance_import_lots';

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
  String? _selectedRowId;
  int _currentPage = 0;
  int _pageSize = 40;

  List<_HrNominaSummaryRow> _allRows = const <_HrNominaSummaryRow>[];
  List<_HrNominaSummaryRow> _visibleRows = const <_HrNominaSummaryRow>[];

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
      final client = Supabase.instance.client;
      final draftRowsResult = await fetchAllSupabaseRows(
        (from, to) => client
            .from(_kHrNominaDraftRowsTable)
            .select(
              'id,created_at,period_label,employee_id,employee_name,empresa,draft_status,'
              'manual_adjustment_amount,fiscal_net_amount,cash_salary_amount,cash_vacation_amount,'
              'cash_isr_amount,transport_support_amount,holiday_amount,overtime_monetized_amount,'
              'manual_bonus_amount,cash_absence_deduction_amount,cash_infonavit_deduction_amount,'
              'cash_fonacot_deduction_amount,loan_deduction_amount,check_amount,payment_outside_amount,'
              'payment_channel,payment_reference,notes',
            )
            .order('created_at', ascending: false)
            .range(from, to),
      );
      final importLotsResult = await fetchAllSupabaseRows(
        (from, to) => client
            .from(_kHrNominaImportLotsTable)
            .select('id,source,period_label,imported_at')
            .order('imported_at', ascending: false)
            .range(from, to),
      );

      final draftRows = draftRowsResult
          .map(_HrNominaDraftRecord.fromRow)
          .toList(growable: false);
      final importLots = importLotsResult
          .map(_HrNominaImportLotLite.fromRow)
          .toList(growable: false);

      final activePeriodLabel = _resolveActiveNominaPeriodLabel(
        drafts: draftRows,
        lots: importLots,
      );
      final rows = _buildNominaRows(
        draftRows: draftRows,
        activePeriodLabel: activePeriodLabel,
      );

      _allRows = rows;
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

  void _rebuildVisibleRows() {
    final pageCount = _allRows.isEmpty
        ? 1
        : ((_allRows.length - 1) ~/ _pageSize) + 1;
    _currentPage = _currentPage.clamp(0, pageCount - 1);
    final start = (_currentPage * _pageSize).clamp(0, _allRows.length);
    final end = (start + _pageSize).clamp(0, _allRows.length);
    _visibleRows = _allRows.sublist(start, end);
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
    final totalPages = _allRows.isEmpty
        ? 1
        : ((_allRows.length - 1) ~/ _pageSize) + 1;
    if (_currentPage >= totalPages - 1) return;
    _currentPage += 1;
    _rebuildVisibleRows();
  }

  void _changePageSize(int value) {
    _pageSize = value;
    _currentPage = 0;
    _rebuildVisibleRows();
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
      ),
    );
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
                  padding: const EdgeInsets.fromLTRB(56, 4, 8, 0),
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : _HrNominaWorkspace(
                          rows: _visibleRows,
                          totalRows: _allRows.length,
                          selectedCount: visibleSelectionCount,
                          activePeriodLabel: _activePeriodLabel,
                          metrics: metrics,
                          selectedRowId: _selectedRowId,
                          currentPage: _currentPage,
                          totalPages: _allRows.isEmpty
                              ? 1
                              : ((_allRows.length - 1) ~/ _pageSize) + 1,
                          pageSize: _pageSize,
                          onPreviousPage: _currentPage == 0
                              ? null
                              : _previousPage,
                          onNextPage:
                              (((_allRows.isEmpty
                                          ? 1
                                          : ((_allRows.length - 1) ~/
                                                    _pageSize) +
                                                1) -
                                      1) <=
                                  _currentPage)
                              ? null
                              : _nextPage,
                          onPageSizeChanged: _changePageSize,
                          onOpenPrenomina: _openPrenomina,
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

class _HrNominaWorkspace extends StatelessWidget {
  final List<_HrNominaSummaryRow> rows;
  final int totalRows;
  final int selectedCount;
  final String activePeriodLabel;
  final _HrNominaMetrics metrics;
  final String? selectedRowId;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<int> onPageSizeChanged;
  final Future<void> Function() onOpenPrenomina;
  final ValueChanged<_HrNominaSummaryRow> onSelectRow;
  final ValueChanged<_HrNominaSummaryRow> onOpenRow;

  const _HrNominaWorkspace({
    required this.rows,
    required this.totalRows,
    required this.selectedCount,
    required this.activePeriodLabel,
    required this.metrics,
    required this.selectedRowId,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPageSizeChanged,
    required this.onOpenPrenomina,
    required this.onSelectRow,
    required this.onOpenRow,
  });

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nómina',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cierre comparativo final entre la corrida capturada en app y la validación externa en Excel.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onOpenPrenomina,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFAF8BFF),
                    foregroundColor: const Color(0xFF24103D),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Volver a prenómina'),
                ),
                _HrNominaMetricChip(label: '$totalRows colaboradores'),
                Text(
                  'Selección: $selectedCount · Cierre: ${activePeriodLabel.isEmpty ? 'Sin periodo activo' : activePeriodLabel}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              _HrNominaContextCard(
                activePeriodLabel: activePeriodLabel,
                selectedCount: selectedCount,
              ),
              _HrNominaSummaryCard(metrics: metrics),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Column(
              children: [
                _HrNominaGridHeader(),
                const SizedBox(height: 10),
                Expanded(
                  child: rows.isEmpty
                      ? _HrNominaEmptyState()
                      : ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            return _HrNominaGridRow(
                              row: row,
                              selected: row.employeeId == selectedRowId,
                              onTap: () => onSelectRow(row),
                              onOpen: () => onOpenRow(row),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 10),
                _HrNominaGridFooter(
                  rows: rows.length,
                  totalRows: totalRows,
                  selectedCount: selectedCount,
                  currentPage: currentPage,
                  totalPages: totalPages,
                  pageSize: pageSize,
                  onPreviousPage: onPreviousPage,
                  onNextPage: onNextPage,
                  onPageSizeChanged: onPageSizeChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HrNominaContextCard extends StatelessWidget {
  final String activePeriodLabel;
  final int selectedCount;

  const _HrNominaContextCard({
    required this.activePeriodLabel,
    required this.selectedCount,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 740,
      child: Card(
        elevation: 0,
        color: const Color(0xFFF5EEFF).withValues(alpha: 0.90),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Contexto del cierre',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6E47A8),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                activePeriodLabel.isEmpty
                    ? 'Sin periodo activo detectado'
                    : activePeriodLabel,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF24103D),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HrNominaSoftPill(label: 'Selección: $selectedCount'),
                  const _HrNominaSoftPill(label: 'Fuente: Prenómina RH'),
                  const _HrNominaSoftPill(label: 'Destino: Validación Nómina'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HrNominaSummaryCard extends StatelessWidget {
  final _HrNominaMetrics metrics;

  const _HrNominaSummaryCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 440,
      child: Card(
        elevation: 0,
        color: const Color(0xFFF5EEFF).withValues(alpha: 0.90),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8D8FF),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      size: 30,
                      color: Color(0xFF6E47A8),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NÓMINA RH',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Color(0xFF6E47A8),
                        ),
                      ),
                      Text(
                        '${metrics.rows}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF24103D),
                        ),
                      ),
                      Text(
                        'Registros del cierre',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(
                            0xFF6E47A8,
                          ).withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HrNominaSoftPill(
                    label: 'Fiscal total: ${_fmtHrNominaMoney(metrics.fiscal)}',
                  ),
                  _HrNominaSoftPill(
                    label:
                        'Fiscal depositado: ${_fmtHrNominaMoney(metrics.fiscalDeposited)}',
                  ),
                  _HrNominaSoftPill(
                    label:
                        'Fiscal en efectivo: ${_fmtHrNominaMoney(metrics.fiscalCash)}',
                  ),
                  _HrNominaSoftPill(
                    label:
                        'Efectivo RH: ${_fmtHrNominaMoney(metrics.operationalCash)}',
                  ),
                  _HrNominaSoftPill(
                    label:
                        'Complementos: ${_fmtHrNominaMoney(metrics.complements)}',
                  ),
                  _HrNominaSoftPill(
                    label:
                        'Deducciones: ${_fmtHrNominaMoney(metrics.deductions)}',
                  ),
                  _HrNominaSoftPill(
                    label:
                        'Fiscal en efectivo capturado: ${_fmtHrNominaMoney(metrics.checks)}',
                  ),
                  _HrNominaSoftPill(
                    label: 'Pago fuera: ${_fmtHrNominaMoney(metrics.outside)}',
                  ),
                  _HrNominaSoftPill(
                    label: 'Total app: ${_fmtHrNominaMoney(metrics.total)}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HrNominaGridHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3ECFF),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 90,
            child: Text('ID', style: _kHrNominaHeaderTextStyle),
          ),
          Expanded(
            flex: 3,
            child: Text('NOMBRE', style: _kHrNominaHeaderTextStyle),
          ),
          Expanded(
            flex: 2,
            child: Text('FISCAL', style: _kHrNominaHeaderTextStyle),
          ),
          Expanded(
            flex: 2,
            child: Text('COMPLEMENTOS', style: _kHrNominaHeaderTextStyle),
          ),
          Expanded(
            flex: 2,
            child: Text('DEDUCCIONES', style: _kHrNominaHeaderTextStyle),
          ),
          Expanded(
            flex: 2,
            child: Text('TOTAL APP', style: _kHrNominaHeaderTextStyle),
          ),
          Expanded(
            flex: 2,
            child: Text('ESTADO', style: _kHrNominaHeaderTextStyle),
          ),
          SizedBox(
            width: 98,
            child: Text(
              'ACCIONES',
              textAlign: TextAlign.center,
              style: _kHrNominaHeaderTextStyle,
            ),
          ),
        ],
      ),
    );
  }
}

const TextStyle _kHrNominaHeaderTextStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w900,
  color: Color(0xFF24103D),
);

class _HrNominaGridRow extends StatelessWidget {
  final _HrNominaSummaryRow row;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  const _HrNominaGridRow({
    required this.row,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        onDoubleTap: onOpen,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFB7A6D6) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? const Color(0xFF9C79FF)
                  : const Color(0xFFE5D7FF),
              width: selected ? 2 : 1.4,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                color: Colors.black.withValues(alpha: 0.08),
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(row.employeeId, style: _rowPrimaryStyle(selected)),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.employeeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _rowPrimaryStyle(selected),
                    ),
                    const SizedBox(height: 4),
                    Text(row.empresa, style: _rowSecondaryStyle(selected)),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _fmtHrNominaMoney(row.fiscalAmount),
                  style: _rowPrimaryStyle(selected),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _fmtHrNominaMoney(row.complementsAmount),
                  style: _rowPrimaryStyle(selected),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _fmtHrNominaMoney(row.deductionsAmount),
                  style: _rowPrimaryStyle(selected),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmtHrNominaMoney(row.totalAmount),
                      style: _rowPrimaryStyle(selected),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      row.paymentChannelLabel,
                      style: _rowSecondaryStyle(selected),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _HrNominaStatusBadge(label: row.statusLabel),
                ),
              ),
              SizedBox(
                width: 98,
                child: Center(
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: selected
                          ? const Color(0xFF7C4DFF)
                          : const Color(0xFFF3ECFF),
                      foregroundColor: selected
                          ? Colors.white
                          : const Color(0xFF6E47A8),
                      minimumSize: const Size(54, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: onOpen,
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _rowPrimaryStyle(bool selected) {
  return TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w900,
    color: selected ? const Color(0xFF24103D) : const Color(0xFF24103D),
  );
}

TextStyle _rowSecondaryStyle(bool selected) {
  return TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: selected
        ? const Color(0xFF6E47A8)
        : const Color(0xFF6E47A8).withValues(alpha: 0.94),
  );
}

class _HrNominaStatusBadge extends StatelessWidget {
  final String label;

  const _HrNominaStatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final bool review = label.toLowerCase().contains('revisión');
    final bool published = label.toLowerCase().contains('publicado');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: review
            ? const Color(0xFFFFF0F2)
            : published
            ? const Color(0xFFEFF7FF)
            : const Color(0xFFF4ECFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: review
              ? const Color(0xFFD59AB1)
              : published
              ? const Color(0xFF9BBEF9)
              : const Color(0xFFC8ABFF),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: review
              ? const Color(0xFF913E5B)
              : published
              ? const Color(0xFF255691)
              : const Color(0xFF6E47A8),
        ),
      ),
    );
  }
}

class _HrNominaEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 44, color: Colors.white70),
          SizedBox(height: 12),
          Text(
            'No hay borradores de prenómina listos para convertirse en cierre de nómina.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
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
        color: const Color(0xFFF0E6FF).withValues(alpha: 0.56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                style: _hrNominaActionOutlinedButtonStyle(),
                onPressed: onPreviousPage,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Anterior'),
              ),
              Text('Página ${currentPage + 1} de $totalPages'),
              OutlinedButton.icon(
                style: _hrNominaActionOutlinedButtonStyle(),
                onPressed: onNextPage,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Siguiente'),
              ),
              const Text('Filas/pág:'),
              SizedBox(
                width: 90,
                child: DropdownButtonFormField<int>(
                  initialValue: pageSize,
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
              Text('Mostrando: $rows'),
              Text('Total: $totalRows'),
              Text('Selección: $selectedCount'),
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
    return Row(
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
        const Column(
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
                color: Color(0xFFCFAEFF),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HrNominaMetricChip extends StatelessWidget {
  final String label;

  const _HrNominaMetricChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFC8ABFF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: Color(0xFF6E47A8),
        ),
      ),
    );
  }
}

class _HrNominaSoftPill extends StatelessWidget {
  final String label;

  const _HrNominaSoftPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4ECFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD2BEFF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Color(0xFF2B1946),
        ),
      ),
    );
  }
}

class _HrNominaDetailDialog extends StatelessWidget {
  final _HrNominaSummaryRow row;
  final String activePeriodLabel;

  const _HrNominaDetailDialog({
    required this.row,
    required this.activePeriodLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 760),
        child: ContractGlassCard(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detalle de nómina',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Vista comparativa del cierre generado desde la app.',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFCFAEFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 280,
                      child: Card(
                        elevation: 0,
                        color: const Color(0xFFF4ECFF).withValues(alpha: 0.92),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.employeeName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF24103D),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'ID ${row.employeeId}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF6E47A8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                row.empresa,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6E47A8),
                                ),
                              ),
                              const SizedBox(height: 18),
                              _HrNominaStatusBadge(label: row.statusLabel),
                              const SizedBox(height: 18),
                              _HrNominaSideData(
                                label: 'Periodo',
                                value: activePeriodLabel.isEmpty
                                    ? 'Sin periodo'
                                    : activePeriodLabel,
                              ),
                              _HrNominaSideData(
                                label: 'Canal de pago',
                                value: row.paymentChannelLabel,
                              ),
                              _HrNominaSideData(
                                label: 'Referencia',
                                value: row.paymentReference.isEmpty
                                    ? '--'
                                    : row.paymentReference,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _HrNominaDetailBlock(
                              title: 'Fiscal y app',
                              rows: [
                                _HrNominaDetailLine(
                                  label: 'Fiscal total',
                                  value: _fmtHrNominaMoney(row.fiscalAmount),
                                ),
                                _HrNominaDetailLine(
                                  label: 'Fiscal depositado',
                                  value: _fmtHrNominaMoney(
                                    row.fiscalDepositedAmount,
                                  ),
                                ),
                                _HrNominaDetailLine(
                                  label: 'Fiscal en efectivo',
                                  value: _fmtHrNominaMoney(
                                    row.fiscalCashAmount,
                                  ),
                                ),
                                _HrNominaDetailLine(
                                  label: 'Complementos RH',
                                  value: _fmtHrNominaMoney(
                                    row.complementsAmount,
                                  ),
                                ),
                                _HrNominaDetailLine(
                                  label: 'Deducciones RH',
                                  value: _fmtHrNominaMoney(
                                    row.deductionsAmount,
                                  ),
                                ),
                                _HrNominaDetailLine(
                                  label: 'Pago por fuera',
                                  value: _fmtHrNominaMoney(
                                    row.paymentOutsideAmount,
                                  ),
                                ),
                                _HrNominaDetailLine(
                                  label: 'Total app',
                                  value: _fmtHrNominaMoney(row.totalAmount),
                                  emphasized: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _HrNominaDetailBlock(
                              title: 'Desglose operativo RH',
                              rows: [
                                _HrNominaDetailLine(
                                  label: 'Sueldo efectivo',
                                  value: _fmtHrNominaMoney(
                                    row.cashSalaryAmount,
                                  ),
                                ),
                                _HrNominaDetailLine(
                                  label: 'Vacaciones efectivo',
                                  value: _fmtHrNominaMoney(
                                    row.cashVacationAmount,
                                  ),
                                ),
                                _HrNominaDetailLine(
                                  label: 'Apoyo transporte',
                                  value: _fmtHrNominaMoney(
                                    row.transportSupportAmount,
                                  ),
                                ),
                                _HrNominaDetailLine(
                                  label: 'Festivo',
                                  value: _fmtHrNominaMoney(row.holidayAmount),
                                ),
                                _HrNominaDetailLine(
                                  label: 'Horas extra',
                                  value: _fmtHrNominaMoney(
                                    row.overtimeMonetizedAmount,
                                  ),
                                ),
                                _HrNominaDetailLine(
                                  label: 'Bono manual',
                                  value: _fmtHrNominaMoney(
                                    row.manualBonusAmount,
                                  ),
                                ),
                                _HrNominaDetailLine(
                                  label: 'Ajuste manual',
                                  value: _fmtHrNominaMoney(
                                    row.manualAdjustmentAmount,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _HrNominaDetailBlock(
                              title: 'Deducciones RH',
                              rows: [
                                _HrNominaDetailLine(
                                  label: 'ISR efectivo',
                                  value: _fmtHrNominaMoney(row.cashIsrAmount),
                                ),
                                _HrNominaDetailLine(
                                  label: 'Descuento ausencia',
                                  value: _fmtHrNominaMoney(
                                    row.cashAbsenceDeductionAmount,
                                  ),
                                ),
                                _HrNominaDetailLine(
                                  label: 'INFONAVIT efectivo',
                                  value: _fmtHrNominaMoney(
                                    row.cashInfonavitDeductionAmount,
                                  ),
                                ),
                                _HrNominaDetailLine(
                                  label: 'FONACOT efectivo',
                                  value: _fmtHrNominaMoney(
                                    row.cashFonacotDeductionAmount,
                                  ),
                                ),
                                _HrNominaDetailLine(
                                  label: 'Préstamo',
                                  value: _fmtHrNominaMoney(
                                    row.loanDeductionAmount,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _HrNominaDetailBlock(
                              title: 'Notas',
                              rows: [
                                _HrNominaDetailLine(
                                  label: 'Observaciones',
                                  value: row.notes.isEmpty ? '--' : row.notes,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    return Card(
      elevation: 0,
      color: const Color(0xFFF4ECFF).withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF24103D),
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
    final Color valueColor = emphasized
        ? const Color(0xFF24103D)
        : const Color(0xFF3A2758);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6E47A8),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: emphasized ? 16 : 14,
              fontWeight: FontWeight.w900,
              color: valueColor,
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF6E47A8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF24103D),
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

class _HrNominaDraftRecord {
  final String employeeId;
  final String employeeName;
  final String empresa;
  final String periodLabel;
  final DateTime? createdAt;
  final String draftStatus;
  final double manualAdjustmentAmount;
  final double fiscalNetAmount;
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

  const _HrNominaDraftRecord({
    required this.employeeId,
    required this.employeeName,
    required this.empresa,
    required this.periodLabel,
    required this.createdAt,
    required this.draftStatus,
    required this.manualAdjustmentAmount,
    required this.fiscalNetAmount,
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
  });

  factory _HrNominaDraftRecord.fromRow(Map<String, dynamic> row) {
    return _HrNominaDraftRecord(
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
    );
  }
}

class _HrNominaSummaryRow {
  final String employeeId;
  final String employeeName;
  final String empresa;
  final String statusLabel;
  final String paymentChannelLabel;
  final String paymentReference;
  final String notes;
  final double fiscalAmount;
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
    required this.employeeId,
    required this.employeeName,
    required this.empresa,
    required this.statusLabel,
    required this.paymentChannelLabel,
    required this.paymentReference,
    required this.notes,
    required this.fiscalAmount,
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

  double get fiscalCashAmount => checkAmount;

  double get fiscalDepositedAmount {
    final amount = fiscalAmount - fiscalCashAmount;
    return amount < 0 ? 0 : amount;
  }

  double get operationalCashAmount => complementsAmount - deductionsAmount;
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
      checks += row.checkAmount;
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

String _resolveActiveNominaPeriodLabel({
  required List<_HrNominaDraftRecord> drafts,
  required List<_HrNominaImportLotLite> lots,
}) {
  final contpaqLot = lots
      .where((lot) => lot.source.toLowerCase() == 'contpaq')
      .toList(growable: false);
  if (contpaqLot.isNotEmpty && contpaqLot.first.periodLabel.isNotEmpty) {
    return contpaqLot.first.periodLabel;
  }
  for (final draft in drafts) {
    if (draft.periodLabel.isNotEmpty) return draft.periodLabel;
  }
  return '';
}

List<_HrNominaSummaryRow> _buildNominaRows({
  required List<_HrNominaDraftRecord> draftRows,
  required String activePeriodLabel,
}) {
  final sourceRows = activePeriodLabel.isNotEmpty
      ? draftRows
            .where((row) => row.periodLabel == activePeriodLabel)
            .toList(growable: false)
      : draftRows;
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
            draft.cashAbsenceDeductionAmount +
            draft.cashInfonavitDeductionAmount +
            draft.cashFonacotDeductionAmount +
            draft.loanDeductionAmount;
        final total =
            draft.fiscalNetAmount +
            draft.paymentOutsideAmount +
            complements -
            deductions;
        return _HrNominaSummaryRow(
          employeeId: draft.employeeId,
          employeeName: draft.employeeName,
          empresa: draft.empresa,
          statusLabel: _hrNominaDraftStatusLabel(draft.draftStatus),
          paymentChannelLabel: _hrNominaPaymentChannelLabel(
            draft.paymentChannel,
          ),
          paymentReference: draft.paymentReference,
          notes: draft.notes,
          fiscalAmount: draft.fiscalNetAmount,
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
          checkAmount: draft.checkAmount,
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

ButtonStyle _hrNominaActionOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF2B1946),
    side: const BorderSide(color: Color(0xFFC8ABFF)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    textStyle: const TextStyle(fontWeight: FontWeight.w900),
  );
}

InputDecoration _hrNominaFieldDecoration() {
  return InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFD7C2FF)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFD7C2FF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF8C5CFF), width: 1.6),
    ),
  );
}
