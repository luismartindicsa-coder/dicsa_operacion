// ignore_for_file: unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_navigation.dart';
import '../shared/app_shell.dart';
import '../shared/archetypes/auxiliary_surfaces/date_picker_surface.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/number_formatters.dart';
import 'contabilidad_area_chrome.dart';
import 'contabilidad_dashboard_page.dart';
import 'contabilidad_flow_analysis_page.dart';
import 'contabilidad_flow_analysis_store.dart';
import 'contabilidad_income_statement_rules.dart';
import 'contabilidad_income_statement_store.dart';
import 'contabilidad_pdf_export.dart';
import 'contabilidad_theme.dart';
import 'contabilidad_trade_analysis_page.dart';

class ContabilidadIncomeStatementPage extends StatefulWidget {
  final bool instantOpen;

  const ContabilidadIncomeStatementPage({super.key, this.instantOpen = false});

  @override
  State<ContabilidadIncomeStatementPage> createState() =>
      _ContabilidadIncomeStatementPageState();
}

class _ContabilidadIncomeStatementPageState
    extends State<ContabilidadIncomeStatementPage> {
  final ContabilidadIncomeStatementStore _store =
      const ContabilidadIncomeStatementStore();
  final ContabilidadFlowAnalysisStore _periodicFlowStore =
      const ContabilidadFlowAnalysisStore();

  bool _menuOpen = false;
  bool _loading = true;
  String? _error;
  int _windowDays = 7;
  _IncomeStatementTab _selectedTab = _IncomeStatementTab.summary;
  String? _selectedReviewKey;
  final Map<String, _ReviewDecisionDraft> _reviewDrafts =
      <String, _ReviewDecisionDraft>{};
  DateTimeRange? _customRange;
  ContabilidadIncomeStatementDataset? _dataset;
  ContabilidadIncomeStatementDataset? _previousDataset;
  ContabilidadPeriodicFlowDataset? _periodicFlowDataset;
  ContabilidadPeriodicIncomeDataset? _periodicIncomeDataset;
  ContabilidadPeriodicOperationalDataset? _periodicOperationalDataset;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final currentRange = _customRange ?? _defaultWindowRange(_windowDays);
      final previousRange = _previousRange(currentRange);
      final results = await Future.wait<dynamic>([
        _store.load(windowDays: _windowDays, dateRange: _customRange),
        _store.load(windowDays: _windowDays, dateRange: previousRange),
        _periodicFlowStore.loadPeriodic(
          windowDays: _windowDays,
          dateRange: _customRange,
        ),
        _periodicFlowStore.loadPeriodicIncome(
          windowDays: _windowDays,
          dateRange: _customRange,
        ),
        _periodicFlowStore.loadPeriodicOperational(
          windowDays: _windowDays,
          dateRange: _customRange,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _dataset = results[0] as ContabilidadIncomeStatementDataset;
        _previousDataset = results[1] as ContabilidadIncomeStatementDataset;
        _periodicFlowDataset = results[2] as ContabilidadPeriodicFlowDataset;
        _periodicIncomeDataset =
            results[3] as ContabilidadPeriodicIncomeDataset;
        _periodicOperationalDataset =
            results[4] as ContabilidadPeriodicOperationalDataset;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _openDashboard() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ContabilidadDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openTradeBalance() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const ContabilidadTradeAnalysisPage(instantOpen: true),
      ),
    );
  }

  Future<void> _openFlow() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ContabilidadFlowAnalysisPage(instantOpen: true)),
    );
  }

  Future<void> _openIncomeStatement() async {
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const ContabilidadIncomeStatementPage(instantOpen: true),
      ),
    );
  }

  Future<void> _logout() async {
    await signOutAndRouteToLogin(context);
  }

  Future<void> _exportPdf() async {
    final statement = _dataset;
    final payables = _periodicFlowDataset;
    final income = _periodicIncomeDataset;
    final operational = _periodicOperationalDataset;
    if (statement == null ||
        payables == null ||
        income == null ||
        operational == null) {
      return;
    }
    final reviewedExpenses = <ContabilidadReviewedExpensePdfRow>[];
    for (final row in statement.reviewRows) {
      final draft = _reviewDrafts[_reviewKey(row)];
      if (draft == null ||
          !draft.isComplete ||
          draft.treatment != _ReviewTreatment.expense ||
          draft.family == null) {
        continue;
      }
      reviewedExpenses.add(
        ContabilidadReviewedExpensePdfRow(
          label: row.label,
          source: row.sourceLabel,
          family: switch (draft.family!) {
            _ReviewExpenseFamily.operating => 'Operativo',
            _ReviewExpenseFamily.administrative => 'Administrativo',
            _ReviewExpenseFamily.financial => 'Financiero',
            _ReviewExpenseFamily.payroll => 'Nomina',
          },
          amount: row.amount,
        ),
      );
    }
    await exportContabilidadIncomeStatementPdf(
      statement: statement,
      payables: payables,
      income: income,
      operational: operational,
      reviewedExpenses: reviewedExpenses,
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initialRange = _customRange ?? _defaultWindowRange(_windowDays);
    final picked = await showContractDateRangePickerSurface(
      context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initialRange,
      title: 'Selecciona el rango de fechas',
      tokens: contabilidadAreaTokens,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = picked;
    });
    await _load();
  }

  Future<void> _setWindowDays(int value) async {
    setState(() {
      _windowDays = value;
      _customRange = null;
    });
    await _load();
  }

  String _money(num value) => formatMoney(value);

  String _rangeLabel() {
    final range = _customRange ?? _dataset?.range;
    if (_customRange == null) return 'Últimos $_windowDays días';
    return _formatRangeLabel(range);
  }

  DateTimeRange _defaultWindowRange(int windowDays) {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: windowDays - 1)),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  DateTimeRange _previousRange(DateTimeRange current) {
    final totalDays = current.end.difference(current.start).inDays + 1;
    final previousEnd = current.start.subtract(const Duration(days: 1));
    final previousStart = previousEnd.subtract(Duration(days: totalDays - 1));
    return DateTimeRange(start: previousStart, end: previousEnd);
  }

  String _statusLabel(ContabilidadIncomeStatementSnapshot snapshot) {
    if (snapshot.periodResult > 0.009) {
      return 'Resultado positivo';
    }
    if (snapshot.periodResult < -0.009) {
      return 'Resultado negativo';
    }
    return 'Resultado neutro';
  }

  Color _statusColor(ContabilidadIncomeStatementSnapshot snapshot) {
    return switch (_statusLabel(snapshot)) {
      'Resultado positivo' => kContabilidadSuccess,
      'Resultado negativo' => const Color(0xFFFF8A80),
      _ => kContabilidadGlow,
    };
  }

  IconData _statusIcon(ContabilidadIncomeStatementSnapshot snapshot) {
    return switch (_statusLabel(snapshot)) {
      'Resultado positivo' => Icons.check_circle_rounded,
      'Resultado negativo' => Icons.warning_amber_rounded,
      _ => Icons.horizontal_rule_rounded,
    };
  }

  String _mainReading(ContabilidadIncomeStatementSnapshot snapshot) {
    if (snapshot.periodResult > 0.009) {
      return 'Después de costo y gastos reconocidos, el periodo sigue dejando resultado positivo.';
    }
    if (snapshot.periodResult < -0.009) {
      return 'Después de costo y gastos reconocidos, el periodo ya se está yendo a pérdida.';
    }
    return 'Después de costo y gastos reconocidos, el periodo está prácticamente empatado.';
  }

  String _proposal(ContabilidadIncomeStatementSnapshot snapshot) {
    if (snapshot.reviewPending > snapshot.recognizedExpenses * 0.20 &&
        snapshot.reviewPending > 0.009) {
      return 'Conviene limpiar primero lo que está en revisión antes de usar este resultado para una lectura contable más dura.';
    }
    if (snapshot.financialExpense > snapshot.operatingExpense &&
        snapshot.financialExpense > 0.009) {
      return 'Conviene revisar gasto financiero y separar interés real contra pagos de pasivo o tarjeta.';
    }
    if (snapshot.periodResult < -0.009) {
      return 'Conviene revisar de inmediato si la presión viene del costo comercial o de los gastos reconocidos.';
    }
    return 'La siguiente mejora natural es bajar al análisis de gastos para explicar mejor de dónde salió cada familia de gasto.';
  }

  double? _changePercent(double current, double previous) {
    if (previous.abs() <= 0.009) return null;
    return ((current - previous) / previous.abs()) * 100;
  }

  String? _changeLabel(double current, double previous) {
    final change = _changePercent(current, previous);
    if (change == null) return null;
    final direction = change >= 0 ? '↑' : '↓';
    return '$direction ${change.abs().toStringAsFixed(0)}% vs periodo anterior';
  }

  String _reviewKey(ContabilidadIncomeStatementReviewRow row) {
    return '${row.sourceLabel}|${row.label}|${row.reason}|${row.suggestedTreatment}';
  }

  void _selectReviewRow(ContabilidadIncomeStatementReviewRow row) {
    setState(() {
      _selectedReviewKey = _reviewKey(row);
    });
  }

  void _updateReviewDraft(
    ContabilidadIncomeStatementReviewRow row,
    _ReviewDecisionDraft Function(_ReviewDecisionDraft current) update,
  ) {
    final key = _reviewKey(row);
    setState(() {
      final current = _reviewDrafts[key] ?? const _ReviewDecisionDraft();
      _reviewDrafts[key] = update(current);
      _selectedReviewKey ??= key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataset = _dataset;
    final previousDataset = _previousDataset;
    return AreaThemeScope(
      tokens: contabilidadAreaTokens,
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape && _menuOpen) {
            setState(() => _menuOpen = false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AppShell(
          background: const ContabilidadAreaBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
          leadingBuilder: (_, _) => ContabilidadPageHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, contentAnim) => ContabilidadPageHeaderBrand(
            contentAnim: contentAnim,
            title: 'Estado de Resultados',
          ),
          trailingBuilder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ContabilidadPageHeaderButton(
                label: 'PDF',
                icon: Icons.picture_as_pdf_rounded,
                width: 104,
                onTap: _exportPdf,
              ),
              const SizedBox(width: 10),
              ContabilidadPageHeaderButton(
                label: 'Recargar',
                icon: Icons.refresh_rounded,
                width: 132,
                onTap: _load,
              ),
              const SizedBox(width: 10),
              ContabilidadPageHeaderButton(
                label: 'Cerrar sesión',
                icon: Icons.logout_rounded,
                onTap: _logout,
              ),
            ],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1480),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 56, right: 2),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _IncomeStatementToolbar(
                            selectedRangeDays: _customRange == null
                                ? _windowDays
                                : null,
                            rangeLabel: _rangeLabel(),
                            onSetLast7Days: () => _setWindowDays(7),
                            onSetLast30Days: () => _setWindowDays(30),
                            onSetLast90Days: () => _setWindowDays(90),
                            onPickDateRange: _pickCustomRange,
                          ),
                          const SizedBox(height: 14),
                          if (_loading)
                            const _IncomeStatementLoadingState()
                          else if (_error != null)
                            _IncomeStatementErrorState(
                              message: _error!,
                              onRetry: _load,
                            )
                          else if (dataset != null) ...[
                            _IncomeStatementSectionTabs(
                              selectedTab: _selectedTab,
                              reviewCount: dataset.reviewRows.length,
                              onSelectTab: (tab) =>
                                  setState(() => _selectedTab = tab),
                            ),
                            const SizedBox(height: 14),
                            _IncomeStatementTabContent(
                              selectedTab: _selectedTab,
                              dataset: dataset,
                              previousDataset: previousDataset,
                              periodicFlowDataset: _periodicFlowDataset,
                              periodicIncomeDataset: _periodicIncomeDataset,
                              periodicOperationalDataset:
                                  _periodicOperationalDataset,
                              money: _money,
                              changeLabel: _changeLabel,
                              statusLabel: _statusLabel(dataset.snapshot),
                              statusColor: _statusColor(dataset.snapshot),
                              statusIcon: _statusIcon(dataset.snapshot),
                              mainReading: _mainReading(dataset.snapshot),
                              proposal: _proposal(dataset.snapshot),
                              selectedReviewKey: _selectedReviewKey,
                              reviewDrafts: _reviewDrafts,
                              onSelectReviewRow: _selectReviewRow,
                              onUpdateReviewDraft: _updateReviewDraft,
                            ),
                          ],
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_menuOpen)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 312,
                  child: ContabilidadAreaSidePanel(
                    label: 'Contabilidad',
                    canReturnToDirection: false,
                    areaItems: buildContabilidadAreaItems(
                      current: ContabilidadAreaScreen.estadoResultados,
                      onOpenTradeBalance: _openTradeBalance,
                      onOpenFlujoGeneral: _openFlow,
                      onOpenEstadoResultados: _openIncomeStatement,
                    ),
                    accessItems: buildContabilidadAccessItems(
                      current: ContabilidadAreaScreen.estadoResultados,
                      onOpenDashboard: _openDashboard,
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

enum _IncomeStatementTab { summary, periodInvoices, expenses, review, audit }

enum _ReviewTreatment {
  expense,
  internal,
  liabilityCapital,
  adjustment,
  outOfPeriod,
}

enum _ReviewExpenseFamily { operating, administrative, payroll, financial }

class _ReviewDecisionDraft {
  final _ReviewTreatment? treatment;
  final _ReviewExpenseFamily? family;
  final String comment;

  const _ReviewDecisionDraft({this.treatment, this.family, this.comment = ''});

  bool get isComplete {
    if (treatment == null) return false;
    if (treatment == _ReviewTreatment.expense) return family != null;
    return true;
  }

  _ReviewDecisionDraft copyWith({
    _ReviewTreatment? treatment,
    _ReviewExpenseFamily? family,
    String? comment,
    bool clearFamily = false,
  }) {
    return _ReviewDecisionDraft(
      treatment: treatment ?? this.treatment,
      family: clearFamily ? null : family ?? this.family,
      comment: comment ?? this.comment,
    );
  }
}

class _IncomeStatementSectionTabs extends StatelessWidget {
  final _IncomeStatementTab selectedTab;
  final int reviewCount;
  final ValueChanged<_IncomeStatementTab> onSelectTab;

  const _IncomeStatementSectionTabs({
    required this.selectedTab,
    required this.reviewCount,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _TabPill(
            label: 'Resumen',
            active: selectedTab == _IncomeStatementTab.summary,
            onTap: () => onSelectTab(_IncomeStatementTab.summary),
          ),
          _TabPill(
            label: 'Facturas del periodo',
            active: selectedTab == _IncomeStatementTab.periodInvoices,
            onTap: () => onSelectTab(_IncomeStatementTab.periodInvoices),
          ),
          _TabPill(
            label: 'Gastos',
            active: selectedTab == _IncomeStatementTab.expenses,
            onTap: () => onSelectTab(_IncomeStatementTab.expenses),
          ),
          _TabPill(
            label: 'Revisión ${reviewCount > 0 ? '($reviewCount)' : ''}',
            active: selectedTab == _IncomeStatementTab.review,
            onTap: () => onSelectTab(_IncomeStatementTab.review),
            accent: const Color(0xFFFFD58A),
          ),
          _TabPill(
            label: 'Auditoría',
            active: selectedTab == _IncomeStatementTab.audit,
            onTap: () => onSelectTab(_IncomeStatementTab.audit),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? accent;

  const _TabPill({
    required this.label,
    required this.active,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? kContabilidadGlow;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: active
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: active
                ? color.withValues(alpha: 0.36)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : kContabilidadMutedInk,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _IncomeStatementTabContent extends StatelessWidget {
  final _IncomeStatementTab selectedTab;
  final ContabilidadIncomeStatementDataset dataset;
  final ContabilidadIncomeStatementDataset? previousDataset;
  final ContabilidadPeriodicFlowDataset? periodicFlowDataset;
  final ContabilidadPeriodicIncomeDataset? periodicIncomeDataset;
  final ContabilidadPeriodicOperationalDataset? periodicOperationalDataset;
  final String Function(num value) money;
  final String? Function(double current, double previous) changeLabel;
  final String statusLabel;
  final Color statusColor;
  final IconData statusIcon;
  final String mainReading;
  final String proposal;
  final String? selectedReviewKey;
  final Map<String, _ReviewDecisionDraft> reviewDrafts;
  final void Function(ContabilidadIncomeStatementReviewRow row)
  onSelectReviewRow;
  final void Function(
    ContabilidadIncomeStatementReviewRow row,
    _ReviewDecisionDraft Function(_ReviewDecisionDraft current) update,
  )
  onUpdateReviewDraft;

  const _IncomeStatementTabContent({
    required this.selectedTab,
    required this.dataset,
    required this.previousDataset,
    required this.periodicFlowDataset,
    required this.periodicIncomeDataset,
    required this.periodicOperationalDataset,
    required this.money,
    required this.changeLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
    required this.mainReading,
    required this.proposal,
    required this.selectedReviewKey,
    required this.reviewDrafts,
    required this.onSelectReviewRow,
    required this.onUpdateReviewDraft,
  });

  @override
  Widget build(BuildContext context) {
    return switch (selectedTab) {
      _IncomeStatementTab.summary => _IncomeStatementSummaryTab(
        dataset: dataset,
        previousDataset: previousDataset,
        money: money,
        changeLabel: changeLabel,
        statusLabel: statusLabel,
        statusColor: statusColor,
        statusIcon: statusIcon,
        mainReading: mainReading,
      ),
      _IncomeStatementTab.periodInvoices => _IncomeStatementPeriodInvoicesTab(
        dataset: periodicFlowDataset,
        incomeDataset: periodicIncomeDataset,
        operationalDataset: periodicOperationalDataset,
        money: money,
      ),
      _IncomeStatementTab.expenses => _IncomeStatementExpensesTab(
        dataset: dataset,
        money: money,
      ),
      _IncomeStatementTab.review => _IncomeStatementReviewTabView(
        dataset: dataset,
        money: money,
        selectedReviewKey: selectedReviewKey,
        reviewDrafts: reviewDrafts,
        onSelectReviewRow: onSelectReviewRow,
        onUpdateReviewDraft: onUpdateReviewDraft,
      ),
      _IncomeStatementTab.audit => _IncomeStatementAuditTabView(
        dataset: dataset,
        money: money,
      ),
    };
  }
}

class _IncomeStatementToolbar extends StatelessWidget {
  final int? selectedRangeDays;
  final String rangeLabel;
  final VoidCallback onSetLast7Days;
  final VoidCallback onSetLast30Days;
  final VoidCallback onSetLast90Days;
  final VoidCallback onPickDateRange;

  const _IncomeStatementToolbar({
    required this.selectedRangeDays,
    required this.rangeLabel,
    required this.onSetLast7Days,
    required this.onSetLast30Days,
    required this.onSetLast90Days,
    required this.onPickDateRange,
  });

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _FilterPill(
            label: '7 días',
            active: selectedRangeDays == 7,
            onTap: onSetLast7Days,
          ),
          _FilterPill(
            label: '30 días',
            active: selectedRangeDays == 30,
            onTap: onSetLast30Days,
          ),
          _FilterPill(
            label: '90 días',
            active: selectedRangeDays == 90,
            onTap: onSetLast90Days,
          ),
          _FilterPill(
            label: rangeLabel,
            active: selectedRangeDays == null,
            icon: Icons.date_range_rounded,
            onTap: onPickDateRange,
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final IconData? icon;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: active
              ? kContabilidadGlow.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: active
                ? kContabilidadGlow.withValues(alpha: 0.40)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: active ? kContabilidadGlow : Colors.white,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : kContabilidadMutedInk,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeStatementHeroPanel extends StatelessWidget {
  final ContabilidadIncomeStatementSnapshot snapshot;
  final ContabilidadIncomeStatementSnapshot? previousSnapshot;
  final String Function(num value) money;
  final String? Function(double current, double previous) changeLabel;
  final String statusLabel;
  final Color statusColor;
  final IconData statusIcon;
  final String mainReading;

  const _IncomeStatementHeroPanel({
    required this.snapshot,
    required this.previousSnapshot,
    required this.money,
    required this.changeLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
    required this.mainReading,
  });

  @override
  Widget build(BuildContext context) {
    final previous = previousSnapshot;
    final resultChange = previous == null
        ? null
        : changeLabel(snapshot.periodResult, previous.periodResult);
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.32),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'RESULTADO DEL PERIODO',
            style: TextStyle(
              color: kContabilidadGlow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.9,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            money(snapshot.periodResult),
            style: TextStyle(
              color: snapshot.periodResult >= 0
                  ? kContabilidadSuccess
                  : const Color(0xFFFF8A80),
              fontSize: 42,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          if (resultChange != null) ...[
            const SizedBox(height: 8),
            Text(
              resultChange,
              style: const TextStyle(
                color: kContabilidadMutedInk,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            mainReading,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeStatementKpiStrip extends StatelessWidget {
  final ContabilidadIncomeStatementSnapshot snapshot;

  const _IncomeStatementKpiStrip({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiChip(
        label: 'Ingresos',
        value: formatMoney(snapshot.revenue),
        accent: kContabilidadSuccess,
      ),
      _KpiChip(
        label: 'Costo comercial',
        value: formatMoney(snapshot.commercialCost),
        accent: kContabilidadMint,
      ),
      _KpiChip(
        label: 'Gastos reconocidos',
        value: formatMoney(snapshot.recognizedExpenses),
        accent: kContabilidadGlow,
      ),
      _KpiChip(
        label: 'Fuera por revisión',
        value: formatMoney(snapshot.reviewPending),
        accent: const Color(0xFFFFD58A),
      ),
    ];
    return ContractGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Wrap(spacing: 10, runSpacing: 10, children: cards),
    );
  }
}

class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _KpiChip({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeStatementLinesPanel extends StatelessWidget {
  final ContabilidadIncomeStatementSnapshot snapshot;
  final List<ContabilidadIncomeStatementLine> lines;
  final String Function(num value) money;

  const _IncomeStatementLinesPanel({
    required this.snapshot,
    required this.lines,
    required this.money,
  });

  Color _tone(ColorTone tone) {
    switch (tone) {
      case ColorTone.positive:
        return kContabilidadSuccess;
      case ColorTone.caution:
        return const Color(0xFFFFD58A);
      case ColorTone.negative:
        return const Color(0xFFFF8A80);
      case ColorTone.neutral:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ESTADO DE RESULTADOS',
            style: TextStyle(
              color: kContabilidadGlow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Utilidad del periodo = ingresos - costo comercial - gastos reconocidos.',
            style: TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 13.4,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _ResultBridgeChart(snapshot: snapshot, money: money),
          const SizedBox(height: 16),
          for (var i = 0; i < lines.length; i++) ...[
            _StatementLineTile(
              label: lines[i].label,
              value: money(lines[i].amount),
              color: _tone(lines[i].tone),
              emphasis: lines[i].emphasis,
            ),
            if (i != lines.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _StatementLineTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool emphasis;

  const _StatementLineTile({
    required this.label,
    required this.value,
    required this.color,
    required this.emphasis,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: emphasis
            ? color.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: emphasis
              ? color.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: emphasis ? 15.5 : 14,
                fontWeight: emphasis ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: emphasis ? 16.5 : 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeStatementSourcesPanel extends StatelessWidget {
  final List<ContabilidadIncomeStatementSourceRow> rows;
  final String Function(num value) money;

  const _IncomeStatementSourcesPanel({required this.rows, required this.money});

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FUENTES DE GASTO RECONOCIDO',
            style: TextStyle(
              color: kContabilidadGlow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            _SourceContributionTile(row: rows[i], money: money),
            if (i != rows.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SourceContributionTile extends StatelessWidget {
  final ContabilidadIncomeStatementSourceRow row;
  final String Function(num value) money;

  const _SourceContributionTile({required this.row, required this.money});

  @override
  Widget build(BuildContext context) {
    final total =
        row.recognizedExpenses + row.internalExcluded + row.reviewPending;
    final recognizedShare = total <= 0.009
        ? 0.0
        : row.recognizedExpenses / total;
    final internalShare = total <= 0.009 ? 0.0 : row.internalExcluded / total;
    final reviewShare = total <= 0.009 ? 0.0 : row.reviewPending / total;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            row.detail,
            style: const TextStyle(color: kContabilidadMutedInk, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _SegmentedBar(
            segments: [
              _BarSegment(
                fraction: recognizedShare,
                color: kContabilidadSuccess,
              ),
              _BarSegment(fraction: internalShare, color: kContabilidadGlow),
              _BarSegment(
                fraction: reviewShare,
                color: const Color(0xFFFFD58A),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _LegendStat(
                label: 'Reconocido',
                value: money(row.recognizedExpenses),
                color: kContabilidadSuccess,
              ),
              _LegendStat(
                label: 'Interno',
                value: money(row.internalExcluded),
                color: kContabilidadGlow,
              ),
              _LegendStat(
                label: 'Revisión',
                value: money(row.reviewPending),
                color: const Color(0xFFFFD58A),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncomeStatementExpensePanel extends StatelessWidget {
  final List<ContabilidadIncomeStatementSourceRow> sourceRows;
  final List<ContabilidadIncomeStatementBreakdownRow> rows;
  final String Function(num value) money;

  const _IncomeStatementExpensePanel({
    required this.sourceRows,
    required this.rows,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DÓNDE SE FUE EL GASTO',
            style: TextStyle(
              color: kContabilidadGlow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Primero se ve qué origen cargó el gasto y después qué rubros fueron los más pesados.',
            style: TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 13.4,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          for (final row in sourceRows) ...[
            _CompactSourceLine(row: row, money: money),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          const Text(
            'PRINCIPALES EGRESOS RECONOCIDOS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Text(
              'Con los filtros actuales todavía no aparecen egresos reconocidos.',
              style: TextStyle(color: kContabilidadMutedInk, fontSize: 13.5),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              _BreakdownRowTile(
                row: rows[i],
                money: money,
                maxAmount: rows.first.amount,
              ),
              if (i != rows.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _BreakdownRowTile extends StatelessWidget {
  final ContabilidadIncomeStatementBreakdownRow row;
  final String Function(num value) money;
  final double maxAmount;

  const _BreakdownRowTile({
    required this.row,
    required this.money,
    required this.maxAmount,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxAmount <= 0.009 ? 0.0 : row.amount / maxAmount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              money(row.amount),
              style: const TextStyle(
                color: kContabilidadGlow,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${row.sourceLabel} · ${row.count} movimientos',
          style: const TextStyle(color: kContabilidadSubtleInk, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        _ValueBar(value: fraction, color: kContabilidadGlow),
      ],
    );
  }
}

class _IncomeStatementExecutivePanel extends StatelessWidget {
  final ContabilidadIncomeStatementSnapshot snapshot;
  final List<ContabilidadIncomeStatementSourceRow> sourceRows;
  final String proposal;
  final List<String> insights;
  final List<String> warnings;
  final String Function(num value) money;

  const _IncomeStatementExecutivePanel({
    required this.snapshot,
    required this.sourceRows,
    required this.proposal,
    required this.insights,
    required this.warnings,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final reviewShare = snapshot.revenue <= 0.009
        ? 0.0
        : (snapshot.reviewPending / snapshot.revenue).clamp(0.0, 1.0);
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LECTURA EJECUTIVA',
            style: TextStyle(
              color: kContabilidadGlow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  proposal,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                _ExecutiveStatRow(
                  label: 'Resultado comercial',
                  value: money(snapshot.commercialResult),
                  color: kContabilidadSuccess,
                ),
                const SizedBox(height: 8),
                _ExecutiveStatRow(
                  label: 'Gasto reconocido',
                  value: money(snapshot.recognizedExpenses),
                  color: kContabilidadGlow,
                ),
                const SizedBox(height: 8),
                _ExecutiveStatRow(
                  label: 'Fuera por revisión',
                  value: money(snapshot.reviewPending),
                  color: const Color(0xFFFFD58A),
                ),
                const SizedBox(height: 8),
                _ValueBar(value: reviewShare, color: const Color(0xFFFFD58A)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'INSIGHTS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in insights) ...[
            _BulletLine(
              icon: Icons.check_circle_outline_rounded,
              color: kContabilidadSuccess,
              text: item,
            ),
            const SizedBox(height: 8),
          ],
          for (final item in warnings) ...[
            _BulletLine(
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFFFD58A),
              text: item,
            ),
            const SizedBox(height: 8),
          ],
          if (sourceRows.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'FUENTES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            for (final row in sourceRows) ...[
              _CompactSourceLine(row: row, money: money),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _IncomeStatementReviewPanel extends StatelessWidget {
  final ContabilidadIncomeStatementSnapshot snapshot;
  final List<ContabilidadIncomeStatementReviewRow> rows;
  final String Function(num value) money;

  const _IncomeStatementReviewPanel({
    required this.snapshot,
    required this.rows,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PARTIDAS EN REVISIÓN',
            style: TextStyle(
              color: Color(0xFFFFD58A),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Estas partidas sí movieron dinero, pero todavía no deben tocar utilidad hasta que se dictamine su tratamiento contable. Hoy representan ${money(snapshot.reviewPending)}.',
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Text(
              'Con los filtros actuales no hay partidas pendientes de revisión.',
              style: TextStyle(color: kContabilidadMutedInk, fontSize: 13.5),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              _ReviewRowTile(row: rows[i], money: money),
              if (i != rows.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ReviewRowTile extends StatelessWidget {
  final ContabilidadIncomeStatementReviewRow row;
  final String Function(num value) money;

  const _ReviewRowTile({required this.row, required this.money});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                money(row.amount),
                style: const TextStyle(
                  color: Color(0xFFFFD58A),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${row.sourceLabel} · ${row.count} movimientos',
            style: const TextStyle(
              color: kContabilidadSubtleInk,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            row.reason,
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 13.3,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sugerencia: ${row.suggestedTreatment}',
            style: const TextStyle(
              color: Color(0xFFFFD58A),
              fontSize: 12.8,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _BulletLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 13.3,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountingFamiliesPanel extends StatelessWidget {
  final List<ContabilidadAccountingFamilyDefinition> rows;

  const _AccountingFamiliesPanel({required this.rows});

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MAPA CONTABLE MAESTRO',
            style: TextStyle(
              color: kContabilidadGlow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Este es el puente que homologa categoría de bancos y rubro de caja o bóveda para que el Estado de Resultados hable un solo idioma contable.',
            style: TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < rows.length; index++) ...[
            _AccountingFamilyTile(row: rows[index]),
            if (index != rows.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _AccountingFamilyTile extends StatelessWidget {
  final ContabilidadAccountingFamilyDefinition row;

  const _AccountingFamilyTile({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bancos: ${row.bankCategories.join(' | ')}',
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Caja/Bóveda: ${row.cashRubrics.join(' | ')}',
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeStatementAuditPanel extends StatelessWidget {
  final List<ContabilidadIncomeStatementSourceRow> sourceRows;
  final List<ContabilidadAccountingFamilyDefinition> familyRows;
  final List<ContabilidadIncomeStatementReviewRow> reviewRows;
  final String Function(num value) money;

  const _IncomeStatementAuditPanel({
    required this.sourceRows,
    required this.familyRows,
    required this.reviewRows,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ContractGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          childrenPadding: const EdgeInsets.only(bottom: 12),
          iconColor: kContabilidadGlow,
          collapsedIconColor: kContabilidadGlow,
          title: const Text(
            'Auditoría y mapa contable',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: const Text(
            'Abre este bloque para validar fuentes, revisión y homologación contable.',
            style: TextStyle(color: kContabilidadMutedInk, fontSize: 12.8),
          ),
          children: [
            _IncomeStatementSourcesPanel(rows: sourceRows, money: money),
            const SizedBox(height: 12),
            if (reviewRows.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  'Partidas hoy en revisión: ${reviewRows.length}',
                  style: const TextStyle(
                    color: kContabilidadMutedInk,
                    fontSize: 13.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _AccountingFamiliesPanel(rows: familyRows),
          ],
        ),
      ),
    );
  }
}

class _ResultBridgeChart extends StatelessWidget {
  final ContabilidadIncomeStatementSnapshot snapshot;
  final String Function(num value) money;

  const _ResultBridgeChart({required this.snapshot, required this.money});

  @override
  Widget build(BuildContext context) {
    final base = snapshot.revenue <= 0.009 ? 1.0 : snapshot.revenue;
    final costShare = (snapshot.commercialCost / base).clamp(0.0, 1.0);
    final expenseShare = (snapshot.recognizedExpenses / base).clamp(0.0, 1.0);
    final resultShare = (snapshot.periodResult.abs() / base).clamp(0.0, 1.0);
    return Column(
      children: [
        _BridgeRow(
          label: 'Ingresos',
          value: money(snapshot.revenue),
          color: kContabilidadSuccess,
          fraction: 1,
        ),
        const SizedBox(height: 10),
        _BridgeRow(
          label: 'Costo comercial',
          value: money(-snapshot.commercialCost),
          color: const Color(0xFFFFD58A),
          fraction: costShare,
        ),
        const SizedBox(height: 10),
        _BridgeRow(
          label: 'Gastos reconocidos',
          value: money(-snapshot.recognizedExpenses),
          color: kContabilidadGlow,
          fraction: expenseShare,
        ),
        const SizedBox(height: 10),
        _BridgeRow(
          label: 'Resultado',
          value: money(snapshot.periodResult),
          color: snapshot.periodResult >= 0
              ? kContabilidadSuccess
              : const Color(0xFFFF8A80),
          fraction: resultShare,
        ),
      ],
    );
  }
}

class _BridgeRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final double fraction;

  const _BridgeRow({
    required this.label,
    required this.value,
    required this.color,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _ValueBar(value: fraction, color: color),
      ],
    );
  }
}

class _ExecutiveStatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ExecutiveStatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 13.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13.8,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _CompactSourceLine extends StatelessWidget {
  final ContabilidadIncomeStatementSourceRow row;
  final String Function(num value) money;

  const _CompactSourceLine({required this.row, required this.money});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            row.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          money(row.recognizedExpenses),
          style: const TextStyle(
            color: kContabilidadGlow,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SegmentedBar extends StatelessWidget {
  final List<_BarSegment> segments;

  const _SegmentedBar({required this.segments});

  @override
  Widget build(BuildContext context) {
    final activeSegments = segments
        .where((segment) => segment.fraction > 0)
        .toList();
    if (activeSegments.isEmpty) {
      return _ValueBar(value: 0, color: Colors.white);
    }
    return SizedBox(
      height: 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Row(
          children: [
            for (final segment in activeSegments)
              Expanded(
                flex: (segment.fraction * 1000).round().clamp(1, 1000),
                child: Container(color: segment.color),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarSegment {
  final double fraction;
  final Color color;

  const _BarSegment({required this.fraction, required this.color});
}

class _LegendStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _LegendStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label $value',
          style: const TextStyle(
            color: kContabilidadSubtleInk,
            fontSize: 12.8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ValueBar extends StatelessWidget {
  final double value;
  final Color color;

  const _ValueBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: clamped,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _IncomeStatementPeriodInvoicesTab extends StatelessWidget {
  final ContabilidadPeriodicFlowDataset? dataset;
  final ContabilidadPeriodicIncomeDataset? incomeDataset;
  final ContabilidadPeriodicOperationalDataset? operationalDataset;
  final String Function(num value) money;

  const _IncomeStatementPeriodInvoicesTab({
    required this.dataset,
    required this.incomeDataset,
    required this.operationalDataset,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final data = dataset;
    if (data == null) {
      return const ContractGlassCard(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContractGlassCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Facturas emitidas y pagadas en este periodo',
                style: TextStyle(
                  color: kContabilidadInk,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Esta lectura explica el periodo: sólo toma facturas fechadas en el rango y sus pagos vinculados dentro del mismo rango.',
                style: TextStyle(
                  color: kContabilidadMutedInk,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _PeriodInvoiceMetric(
                    label: 'Facturado',
                    value: money(data.invoicedAmount),
                    detail: '${data.invoiceCount} facturas del periodo',
                    color: kContabilidadGlow,
                  ),
                  _PeriodInvoiceMetric(
                    label: 'Pagado de esas facturas',
                    value: money(data.paidAmount),
                    detail: 'Pagos bancarios vinculados',
                    color: kContabilidadSuccess,
                  ),
                  _PeriodInvoiceMetric(
                    label: 'Pendiente',
                    value: money(data.pendingAmount),
                    detail: '${data.pendingInvoiceCount} facturas con saldo',
                    color: const Color(0xFFFFB36B),
                  ),
                ],
              ),
              if (incomeDataset != null) ...[
                const SizedBox(height: 18),
                _IncomePeriodSalesSummary(
                  dataset: incomeDataset!,
                  money: money,
                ),
              ],
              if (operationalDataset != null) ...[
                const SizedBox(height: 14),
                _IncomeOperationalSummary(
                  dataset: operationalDataset!,
                  money: money,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final punctual = _PeriodInvoiceReadingCard(
              icon: Icons.schedule_rounded,
              title: 'Puntualidad del pago',
              child: Column(
                children: [
                  _PeriodInvoiceAmountRow(
                    label: 'Pagado a tiempo',
                    value: money(data.paidOnTimeAmount),
                    color: kContabilidadSuccess,
                  ),
                  const SizedBox(height: 11),
                  _PeriodInvoiceAmountRow(
                    label: 'Pagado vencido en este periodo',
                    value: money(data.paidLateAmount),
                    color: const Color(0xFFFFB36B),
                  ),
                ],
              ),
            );
            final contextCard = _PeriodInvoiceReadingCard(
              icon: data.unlinkedPaymentCount > 0
                  ? Icons.link_off_rounded
                  : Icons.fact_check_rounded,
              title: data.unlinkedPaymentCount > 0
                  ? 'Dato por completar'
                  : 'Lectura verificable',
              iconColor: data.unlinkedPaymentCount > 0
                  ? const Color(0xFFFFB36B)
                  : kContabilidadSuccess,
              child: Text(
                _periodContext(data),
                style: const TextStyle(
                  color: kContabilidadMutedInk,
                  height: 1.4,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
            if (constraints.maxWidth < 900) {
              return Column(
                children: [punctual, const SizedBox(height: 16), contextCard],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: punctual),
                const SizedBox(width: 16),
                Expanded(child: contextCard),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        ContractGlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Facturas con mayor importe',
                style: TextStyle(
                  color: kContabilidadInk,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'El detalle conserva separado lo pagado y lo que todavía quedó pendiente en el periodo.',
                style: TextStyle(
                  color: kContabilidadMutedInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              if (data.rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No hay facturas registradas en el periodo.',
                      style: TextStyle(
                        color: kContabilidadMutedInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else
                ...data.rows
                    .take(12)
                    .map(
                      (row) => _PeriodInvoiceDetailRow(row: row, money: money),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  String _periodContext(ContabilidadPeriodicFlowDataset data) {
    final messages = <String>[];
    if (data.paidHistoricalOverdueAmount > 0.009) {
      messages.add(
        'Se pagaron ${money(data.paidHistoricalOverdueAmount)} de ${data.paidHistoricalOverdueCount} factura(s) vencida(s) de periodos anteriores; se muestran aparte y no cambian este resultado.',
      );
    }
    if (data.unlinkedPaymentCount > 0) {
      messages.add(
        'Hay ${data.unlinkedPaymentCount} pago(s) de factura sin vínculo; se excluyeron para no atribuirlos incorrectamente.',
      );
    }
    if (messages.isEmpty) {
      return 'Los pagos incluidos están vinculados explícitamente a una factura del periodo, por lo que se pueden rastrear desde Finanzas.';
    }
    return messages.join('\n\n');
  }
}

class _IncomeOperationalSummary extends StatelessWidget {
  final ContabilidadPeriodicOperationalDataset dataset;
  final String Function(num value) money;

  const _IncomeOperationalSummary({required this.dataset, required this.money});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kContabilidadGlow.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: kContabilidadGlow.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operación: Bóveda y efectivo',
            style: TextStyle(
              color: kContabilidadInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Entradas y salidas fechadas en el periodo. Los traspasos internos de Bóveda no se tratan como gasto.',
            style: TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              Text(
                'Entradas ${money(dataset.vaultInflows + dataset.cashInflows)}',
                style: const TextStyle(
                  color: kContabilidadSuccess,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Salidas ${money(dataset.vaultOutflows + dataset.cashOutflows)}',
                style: const TextStyle(
                  color: Color(0xFFFFD08A),
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Neto ${money(dataset.operationalNet)}',
                style: const TextStyle(
                  color: kContabilidadInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Bóveda ${money(dataset.vaultInflows)} / ${money(dataset.vaultOutflows)} · Efectivo ${money(dataset.cashInflows)} / ${money(dataset.cashOutflows)}${dataset.vaultInternalTransfers > 0.009 ? ' · Internos aislados ${money(dataset.vaultInternalTransfers)}' : ''}',
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomePeriodSalesSummary extends StatelessWidget {
  final ContabilidadPeriodicIncomeDataset dataset;
  final String Function(num value) money;

  const _IncomePeriodSalesSummary({required this.dataset, required this.money});

  @override
  Widget build(BuildContext context) {
    final notes = <String>[];
    if (dataset.collectedHistoricalOverdueAmount > 0.009) {
      notes.add(
        'Cobrado de atrasos anteriores: ${money(dataset.collectedHistoricalOverdueAmount)}; no se mezcla con el resultado del periodo.',
      );
    }
    if (dataset.unlinkedCollectionCount > 0) {
      notes.add(
        '${dataset.unlinkedCollectionCount} cobro(s) sin vínculo a una factura fueron excluidos.',
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kContabilidadSuccess.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: kContabilidadSuccess.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ingresos: ventas mayoristas facturadas',
            style: TextStyle(
              color: kContabilidadInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'El cobro sólo se reconoce si el abono bancario está ligado a la factura de venta.',
            style: TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              Text(
                'Facturado ${money(dataset.invoicedAmount)}',
                style: const TextStyle(
                  color: kContabilidadInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Cobrado ${money(dataset.collectedCurrentAmount)}',
                style: const TextStyle(
                  color: kContabilidadSuccess,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Por cobrar ${money(dataset.pendingAmount)}',
                style: const TextStyle(
                  color: Color(0xFFFFD08A),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              notes.join(' '),
              style: const TextStyle(
                color: kContabilidadMutedInk,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PeriodInvoiceMetric extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final Color color;

  const _PeriodInvoiceMetric({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodInvoiceReadingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Color? iconColor;

  const _PeriodInvoiceReadingCard({
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final tone = iconColor ?? kContabilidadGlow;
    return ContractGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: tone),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: kContabilidadInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PeriodInvoiceAmountRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PeriodInvoiceAmountRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _PeriodInvoiceDetailRow extends StatelessWidget {
  final ContabilidadPeriodicFlowRow row;
  final String Function(num value) money;

  const _PeriodInvoiceDetailRow({required this.row, required this.money});

  @override
  Widget build(BuildContext context) {
    final pending = row.pendingAmount > 0.009;
    final late = !pending && row.hasLatePayment;
    final tone = pending || late
        ? const Color(0xFFFFB36B)
        : kContabilidadSuccess;
    final status = pending
        ? 'Pendiente ${money(row.pendingAmount)}'
        : late
        ? 'Pagada vencida'
        : 'Pagada a tiempo';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 255,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.folio.trim().isEmpty ? 'Factura sin folio' : row.folio,
                  style: const TextStyle(
                    color: kContabilidadInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.provider.trim().isEmpty
                      ? 'Proveedor sin nombre'
                      : row.provider,
                  style: const TextStyle(
                    color: kContabilidadMutedInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Factura ${money(row.invoicedAmount)}',
            style: const TextStyle(
              color: kContabilidadInk,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Pagado ${money(row.paidAmount)}',
            style: const TextStyle(
              color: kContabilidadInk,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: tone,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeStatementSummaryTab extends StatelessWidget {
  final ContabilidadIncomeStatementDataset dataset;
  final ContabilidadIncomeStatementDataset? previousDataset;
  final String Function(num value) money;
  final String? Function(double current, double previous) changeLabel;
  final String statusLabel;
  final Color statusColor;
  final IconData statusIcon;
  final String mainReading;

  const _IncomeStatementSummaryTab({
    required this.dataset,
    required this.previousDataset,
    required this.money,
    required this.changeLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
    required this.mainReading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryTopRow(
          snapshot: dataset.snapshot,
          previousSnapshot: previousDataset?.snapshot,
          money: money,
          changeLabel: changeLabel,
          statusLabel: statusLabel,
          statusColor: statusColor,
          statusIcon: statusIcon,
          mainReading: mainReading,
          reviewGroups: dataset.reviewRows.length,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final singleColumn = constraints.maxWidth < 1080;
            if (singleColumn) {
              return Column(
                children: [
                  _IncomeStatementLinesPanel(
                    snapshot: dataset.snapshot,
                    lines: dataset.lines,
                    money: money,
                  ),
                  const SizedBox(height: 16),
                  _PeriodComparisonPanel(
                    snapshot: dataset.snapshot,
                    previousSnapshot: previousDataset?.snapshot,
                    money: money,
                    changeLabel: changeLabel,
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 8,
                  child: _IncomeStatementLinesPanel(
                    snapshot: dataset.snapshot,
                    lines: dataset.lines,
                    money: money,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: _PeriodComparisonPanel(
                    snapshot: dataset.snapshot,
                    previousSnapshot: previousDataset?.snapshot,
                    money: money,
                    changeLabel: changeLabel,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final singleColumn = constraints.maxWidth < 1080;
            if (singleColumn) {
              return Column(
                children: [
                  _FamilyExpensePanel(
                    rows: dataset.familyExpenseRows,
                    snapshot: dataset.snapshot,
                    money: money,
                  ),
                  const SizedBox(height: 16),
                  _SourceOriginPanel(rows: dataset.sourceRows, money: money),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 8,
                  child: _FamilyExpensePanel(
                    rows: dataset.familyExpenseRows,
                    snapshot: dataset.snapshot,
                    money: money,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: _SourceOriginPanel(
                    rows: dataset.sourceRows,
                    money: money,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _SummaryInsightsPanel(
          snapshot: dataset.snapshot,
          sourceRows: dataset.sourceRows,
          reviewRows: dataset.reviewRows,
          familyRows: dataset.familyExpenseRows,
          money: money,
        ),
      ],
    );
  }
}

class _SummaryTopRow extends StatelessWidget {
  final ContabilidadIncomeStatementSnapshot snapshot;
  final ContabilidadIncomeStatementSnapshot? previousSnapshot;
  final String Function(num value) money;
  final String? Function(double current, double previous) changeLabel;
  final String statusLabel;
  final Color statusColor;
  final IconData statusIcon;
  final String mainReading;
  final int reviewGroups;

  const _SummaryTopRow({
    required this.snapshot,
    required this.previousSnapshot,
    required this.money,
    required this.changeLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
    required this.mainReading,
    required this.reviewGroups,
  });

  @override
  Widget build(BuildContext context) {
    final margin = snapshot.revenue <= 0.009
        ? 0.0
        : (snapshot.periodResult / snapshot.revenue) * 100;
    final cards = [
      _KpiMetricCard(
        label: 'Ingresos',
        value: money(snapshot.revenue),
        accent: kContabilidadSuccess,
        detail: '100% del periodo',
      ),
      _KpiMetricCard(
        label: 'Costo comercial',
        value: money(snapshot.commercialCost),
        accent: const Color(0xFFFFD58A),
        detail:
            '${_percentOf(snapshot.commercialCost, snapshot.revenue)} de ingresos',
      ),
      _KpiMetricCard(
        label: 'Gastos reconocidos',
        value: money(snapshot.recognizedExpenses),
        accent: kContabilidadGlow,
        detail:
            '${_percentOf(snapshot.recognizedExpenses, snapshot.revenue)} de ingresos',
      ),
      _KpiMetricCard(
        label: 'En revisión',
        value: money(snapshot.reviewPending),
        accent: const Color(0xFFFFD58A),
        detail:
            '${_percentOf(snapshot.reviewPending, snapshot.revenue)} de ingresos · $reviewGroups grupos',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final singleColumn = constraints.maxWidth < 1180;
        final hero = _IncomeStatementHeroPanel(
          snapshot: snapshot,
          previousSnapshot: previousSnapshot,
          money: money,
          changeLabel: changeLabel,
          statusLabel: statusLabel,
          statusColor: statusColor,
          statusIcon: statusIcon,
          mainReading:
              '$mainReading Margen neto ${margin.toStringAsFixed(1)}%.',
        );
        final side = Wrap(spacing: 12, runSpacing: 12, children: cards);
        if (singleColumn) {
          return Column(children: [hero, const SizedBox(height: 16), side]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: hero),
            const SizedBox(width: 16),
            Expanded(flex: 6, child: side),
          ],
        );
      },
    );
  }
}

class _KpiMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final String detail;

  const _KpiMetricCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 12.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodComparisonPanel extends StatelessWidget {
  final ContabilidadIncomeStatementSnapshot snapshot;
  final ContabilidadIncomeStatementSnapshot? previousSnapshot;
  final String Function(num value) money;
  final String? Function(double current, double previous) changeLabel;

  const _PeriodComparisonPanel({
    required this.snapshot,
    required this.previousSnapshot,
    required this.money,
    required this.changeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final previous = previousSnapshot;
    final currentMargin = snapshot.revenue <= 0.009
        ? 0.0
        : (snapshot.periodResult / snapshot.revenue) * 100;
    final previousMargin = previous == null || previous.revenue <= 0.009
        ? null
        : (previous.periodResult / previous.revenue) * 100;
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TENDENCIA',
            style: TextStyle(
              color: kContabilidadGlow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          _ExecutiveStatRow(
            label: 'Periodo actual',
            value: money(snapshot.periodResult),
            color: snapshot.periodResult >= 0
                ? kContabilidadSuccess
                : const Color(0xFFFF8A80),
          ),
          const SizedBox(height: 8),
          _ExecutiveStatRow(
            label: 'Margen actual',
            value: '${currentMargin.toStringAsFixed(1)}%',
            color: kContabilidadGlow,
          ),
          if (previous != null) ...[
            const SizedBox(height: 8),
            _ExecutiveStatRow(
              label: 'Periodo anterior',
              value: money(previous.periodResult),
              color: Colors.white,
            ),
            if (previousMargin != null) ...[
              const SizedBox(height: 8),
              _ExecutiveStatRow(
                label: 'Margen anterior',
                value: '${previousMargin.toStringAsFixed(1)}%',
                color: Colors.white,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              changeLabel(snapshot.periodResult, previous.periodResult) ??
                  'Sin comparativo suficiente',
              style: const TextStyle(
                color: kContabilidadMutedInk,
                fontSize: 13.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FamilyExpensePanel extends StatelessWidget {
  final List<ContabilidadIncomeStatementFamilyRow> rows;
  final ContabilidadIncomeStatementSnapshot snapshot;
  final String Function(num value) money;

  const _FamilyExpensePanel({
    required this.rows,
    required this.snapshot,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final maxTotal = rows.isEmpty
        ? 1.0
        : rows
              .map((row) => row.totalAmount)
              .reduce((current, next) => current > next ? current : next);
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GASTOS POR FAMILIA Y FUENTE',
            style: TextStyle(
              color: kContabilidadGlow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Una sola barra por familia maestra, segmentada por el sistema que originó el gasto.',
            style: TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 13.4,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          for (final row in rows) ...[
            _FamilyExpenseRowTile(
              row: row,
              maxTotal: maxTotal,
              overallTotal: snapshot.recognizedExpenses,
              money: money,
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _FamilyExpenseRowTile extends StatelessWidget {
  final ContabilidadIncomeStatementFamilyRow row;
  final double maxTotal;
  final double overallTotal;
  final String Function(num value) money;

  const _FamilyExpenseRowTile({
    required this.row,
    required this.maxTotal,
    required this.overallTotal,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final barShare = maxTotal <= 0.009 ? 0.0 : row.totalAmount / maxTotal;
    final total = row.totalAmount <= 0.009 ? 1.0 : row.totalAmount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              money(row.totalAmount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${_percentOf(row.totalAmount, overallTotal)} del gasto reconocido',
          style: const TextStyle(
            color: kContabilidadMutedInk,
            fontSize: 12.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _ValueBar(value: barShare, color: Colors.white.withValues(alpha: 0.2)),
        const SizedBox(height: 8),
        _SegmentedBar(
          segments: [
            _BarSegment(
              fraction: row.bankAmount / total,
              color: kContabilidadGlow,
            ),
            _BarSegment(
              fraction: row.vaultAmount / total,
              color: const Color(0xFFFFD58A),
            ),
            _BarSegment(
              fraction: row.menudeoAmount / total,
              color: kContabilidadSuccess,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _LegendStat(
              label: 'Bancos',
              value: money(row.bankAmount),
              color: kContabilidadGlow,
            ),
            _LegendStat(
              label: 'Bóveda',
              value: money(row.vaultAmount),
              color: const Color(0xFFFFD58A),
            ),
            _LegendStat(
              label: 'Menudeo',
              value: money(row.menudeoAmount),
              color: kContabilidadSuccess,
            ),
          ],
        ),
      ],
    );
  }
}

class _SourceOriginPanel extends StatelessWidget {
  final List<ContabilidadIncomeStatementSourceRow> rows;
  final String Function(num value) money;

  const _SourceOriginPanel({required this.rows, required this.money});

  @override
  Widget build(BuildContext context) {
    final totalRecognized = rows.fold<double>(
      0,
      (sum, row) => sum + row.recognizedExpenses,
    );
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ORIGEN DEL GASTO',
            style: TextStyle(
              color: kContabilidadGlow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            money(totalRecognized),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'Gasto reconocido',
            style: TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 13.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          for (final row in rows) ...[
            _OriginRowTile(
              row: row,
              totalRecognized: totalRecognized,
              money: money,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _OriginRowTile extends StatelessWidget {
  final ContabilidadIncomeStatementSourceRow row;
  final double totalRecognized;
  final String Function(num value) money;

  const _OriginRowTile({
    required this.row,
    required this.totalRecognized,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = totalRecognized <= 0.009
        ? 0.0
        : row.recognizedExpenses / totalRecognized;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${_percentOf(row.recognizedExpenses, totalRecognized)} · ${money(row.recognizedExpenses)}',
              style: const TextStyle(
                color: kContabilidadGlow,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ValueBar(value: fraction, color: kContabilidadGlow),
      ],
    );
  }
}

class _SummaryInsightsPanel extends StatelessWidget {
  final ContabilidadIncomeStatementSnapshot snapshot;
  final List<ContabilidadIncomeStatementSourceRow> sourceRows;
  final List<ContabilidadIncomeStatementReviewRow> reviewRows;
  final List<ContabilidadIncomeStatementFamilyRow> familyRows;
  final String Function(num value) money;

  const _SummaryInsightsPanel({
    required this.snapshot,
    required this.sourceRows,
    required this.reviewRows,
    required this.familyRows,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final dominantFamily = familyRows.isEmpty
        ? null
        : familyRows.reduce(
            (best, row) => row.totalAmount > best.totalAmount ? row : best,
          );
    final dominantSource = sourceRows.isEmpty
        ? null
        : sourceRows.reduce(
            (best, row) =>
                row.recognizedExpenses > best.recognizedExpenses ? row : best,
          );
    final items = <({IconData icon, Color color, String text})>[
      (
        icon: Icons.check_circle_outline_rounded,
        color: kContabilidadSuccess,
        text:
            'El periodo cerró con margen neto de ${_percentOf(snapshot.periodResult, snapshot.revenue)}.',
      ),
      if (dominantFamily != null)
        (
          icon: Icons.bar_chart_rounded,
          color: kContabilidadGlow,
          text:
              '${dominantFamily.label} representa la mayor familia de gasto: ${_percentOf(dominantFamily.totalAmount, snapshot.recognizedExpenses)}.',
        ),
      if (dominantSource != null)
        (
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFFFFD58A),
          text:
              '${dominantSource.label} originó ${_percentOf(dominantSource.recognizedExpenses, snapshot.recognizedExpenses)} del gasto reconocido.',
        ),
      if (snapshot.reviewPending > 0.009)
        (
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFFFD58A),
          text:
              'Existen ${reviewRows.length} grupos por ${money(snapshot.reviewPending)} pendientes de tratamiento contable.',
        ),
    ];
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INSIGHTS ACCIONABLES',
            style: TextStyle(
              color: kContabilidadGlow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items) ...[
            _BulletLine(icon: item.icon, color: item.color, text: item.text),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _IncomeStatementExpensesTab extends StatelessWidget {
  final ContabilidadIncomeStatementDataset dataset;
  final String Function(num value) money;

  const _IncomeStatementExpensesTab({
    required this.dataset,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FamilyExpensePanel(
          rows: dataset.familyExpenseRows,
          snapshot: dataset.snapshot,
          money: money,
        ),
        const SizedBox(height: 16),
        _ExpenseDetailTable(
          familyRows: dataset.familyExpenseRows,
          money: money,
        ),
      ],
    );
  }
}

class _ExpenseDetailTable extends StatelessWidget {
  final List<ContabilidadIncomeStatementFamilyRow> familyRows;
  final String Function(num value) money;

  const _ExpenseDetailTable({required this.familyRows, required this.money});

  @override
  Widget build(BuildContext context) {
    final detailRows = <({String family, String source, double amount})>[];
    for (final row in familyRows) {
      if (row.bankAmount > 0.009) {
        detailRows.add((
          family: row.label,
          source: 'Bancos',
          amount: row.bankAmount,
        ));
      }
      if (row.vaultAmount > 0.009) {
        detailRows.add((
          family: row.label,
          source: 'Bóveda',
          amount: row.vaultAmount,
        ));
      }
      if (row.menudeoAmount > 0.009) {
        detailRows.add((
          family: row.label,
          source: 'Menudeo',
          amount: row.menudeoAmount,
        ));
      }
    }
    final total = detailRows.fold<double>(0, (sum, row) => sum + row.amount);
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DETALLE DE GASTO',
            style: TextStyle(
              color: kContabilidadGlow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 14),
          for (final row in detailRows) ...[
            _SimpleTableRow(
              leading: '${row.family} · ${row.source}',
              middle: _percentOf(row.amount, total),
              trailing: money(row.amount),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _IncomeStatementReviewTabView extends StatelessWidget {
  final ContabilidadIncomeStatementDataset dataset;
  final String Function(num value) money;
  final String? selectedReviewKey;
  final Map<String, _ReviewDecisionDraft> reviewDrafts;
  final void Function(ContabilidadIncomeStatementReviewRow row)
  onSelectReviewRow;
  final void Function(
    ContabilidadIncomeStatementReviewRow row,
    _ReviewDecisionDraft Function(_ReviewDecisionDraft current) update,
  )
  onUpdateReviewDraft;

  const _IncomeStatementReviewTabView({
    required this.dataset,
    required this.money,
    required this.selectedReviewKey,
    required this.reviewDrafts,
    required this.onSelectReviewRow,
    required this.onUpdateReviewDraft,
  });

  @override
  Widget build(BuildContext context) {
    final selectedRow = dataset.reviewRows
        .cast<ContabilidadIncomeStatementReviewRow?>()
        .firstWhere(
          (row) => row != null && _reviewDecisionKey(row) == selectedReviewKey,
          orElse: () =>
              dataset.reviewRows.isEmpty ? null : dataset.reviewRows.first,
        );
    final preview = _ReviewDecisionPreview.fromDrafts(
      snapshot: dataset.snapshot,
      rows: dataset.reviewRows,
      drafts: reviewDrafts,
    );
    return Column(
      children: [
        ContractGlassCard(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _ReviewStatCard(
                label: 'En revisión',
                value: money(dataset.snapshot.reviewPending),
                detail:
                    '${dataset.reviewRows.length} agrupaciones todavía fuera de utilidad',
                accent: const Color(0xFFFFD58A),
              ),
              _ReviewStatCard(
                label: 'Utilidad actual',
                value: money(dataset.snapshot.periodResult),
                detail: 'Antes de dictaminar revisión',
                accent: dataset.snapshot.periodResult >= 0
                    ? kContabilidadSuccess
                    : const Color(0xFFFF8A80),
              ),
              _ReviewStatCard(
                label: 'Pendiente restante',
                value: money(preview.remainingPending),
                detail: 'Lo que seguiría fuera del resultado',
                accent: kContabilidadGlow,
              ),
              _ReviewStatCard(
                label: 'Utilidad proyectada',
                value: money(preview.projectedResult),
                detail: 'Si aplicas los criterios marcados en esta sesión',
                accent: preview.projectedResult >= 0
                    ? kContabilidadSuccess
                    : const Color(0xFFFF8A80),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 1120;
            final listPanel = _ReviewQueuePanel(
              rows: dataset.reviewRows,
              money: money,
              reviewDrafts: reviewDrafts,
              selectedReviewKey: selectedReviewKey,
              onSelectReviewRow: onSelectReviewRow,
            );
            final detailPanel = _ReviewDecisionWorkspace(
              row: selectedRow,
              money: money,
              draft: selectedRow == null
                  ? null
                  : reviewDrafts[_reviewDecisionKey(selectedRow)],
              onUpdateReviewDraft: onUpdateReviewDraft,
            );
            if (compact) {
              return Column(
                children: [listPanel, const SizedBox(height: 16), detailPanel],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: listPanel),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: detailPanel),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReviewQueuePanel extends StatelessWidget {
  final List<ContabilidadIncomeStatementReviewRow> rows;
  final String Function(num value) money;
  final Map<String, _ReviewDecisionDraft> reviewDrafts;
  final String? selectedReviewKey;
  final void Function(ContabilidadIncomeStatementReviewRow row)
  onSelectReviewRow;

  const _ReviewQueuePanel({
    required this.rows,
    required this.money,
    required this.reviewDrafts,
    required this.selectedReviewKey,
    required this.onSelectReviewRow,
  });

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COLA DE DICTAMINACIÓN',
            style: TextStyle(
              color: Color(0xFFFFD58A),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Selecciona una partida, define su tratamiento y decide si entra o sale de utilidad.',
            style: TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 13.4,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          for (final row in rows) ...[
            _ReviewTableRow(
              row: row,
              money: money,
              draft: reviewDrafts[_reviewDecisionKey(row)],
              selected: selectedReviewKey == _reviewDecisionKey(row),
              onTap: () => onSelectReviewRow(row),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ReviewTableRow extends StatelessWidget {
  final ContabilidadIncomeStatementReviewRow row;
  final String Function(num value) money;
  final _ReviewDecisionDraft? draft;
  final bool selected;
  final VoidCallback onTap;

  const _ReviewTableRow({
    required this.row,
    required this.money,
    required this.draft,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = _reviewStatusLabel(draft);
    final badgeColor = _reviewStatusColor(draft);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected
            ? kContabilidadGlow.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? kContabilidadGlow.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  money(row.amount),
                  style: const TextStyle(
                    color: Color(0xFFFFD58A),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${row.sourceLabel} · ${row.count} movimientos',
              style: const TextStyle(
                color: kContabilidadSubtleInk,
                fontSize: 12.8,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DecisionBadge(label: badge, color: badgeColor),
                if (draft?.treatment == _ReviewTreatment.expense &&
                    draft?.family != null)
                  _DecisionBadge(
                    label: _expenseFamilyLabel(draft!.family!),
                    color: kContabilidadSuccess,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              row.reason,
              style: const TextStyle(
                color: kContabilidadMutedInk,
                fontSize: 13.3,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Posible tratamiento: ${row.suggestedTreatment}',
              style: const TextStyle(
                color: Color(0xFFFFD58A),
                fontSize: 12.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.rule_folder_outlined, size: 16),
                label: Text(selected ? 'Editando' : 'Dictaminar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewDecisionWorkspace extends StatelessWidget {
  final ContabilidadIncomeStatementReviewRow? row;
  final _ReviewDecisionDraft? draft;
  final String Function(num value) money;
  final void Function(
    ContabilidadIncomeStatementReviewRow row,
    _ReviewDecisionDraft Function(_ReviewDecisionDraft current) update,
  )
  onUpdateReviewDraft;

  const _ReviewDecisionWorkspace({
    required this.row,
    required this.draft,
    required this.money,
    required this.onUpdateReviewDraft,
  });

  @override
  Widget build(BuildContext context) {
    if (row == null) {
      return const ContractGlassCard(
        padding: EdgeInsets.all(20),
        child: Text(
          'Selecciona una partida en revisión para empezar a dictaminar.',
          style: TextStyle(color: kContabilidadMutedInk, fontSize: 13.5),
        ),
      );
    }
    final currentDraft = draft ?? const _ReviewDecisionDraft();
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DICTAMINAR PARTIDA',
            style: TextStyle(
              color: kContabilidadGlow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            row!.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${row!.sourceLabel} · ${row!.count} movimientos · ${money(row!.amount)}',
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 13.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            row!.reason,
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 13.3,
              height: 1.4,
            ),
          ),
          if (row!.movements.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'MOVIMIENTOS DENTRO DE LA AGRUPACIÓN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Aquí puedes detectar si la agrupación trae piezas que sí deberían entrar a utilidad y otras que no.',
              style: TextStyle(
                color: kContabilidadMutedInk,
                fontSize: 13.2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            for (final movement in row!.movements) ...[
              _ReviewMovementTile(movement: movement, money: money),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 16),
          const Text(
            'TRATAMIENTO CONTABLE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DecisionOptionChip(
                label: 'Reconocer como gasto',
                active: currentDraft.treatment == _ReviewTreatment.expense,
                color: kContabilidadSuccess,
                onTap: () => onUpdateReviewDraft(
                  row!,
                  (current) =>
                      current.copyWith(treatment: _ReviewTreatment.expense),
                ),
              ),
              _DecisionOptionChip(
                label: 'Movimiento interno',
                active: currentDraft.treatment == _ReviewTreatment.internal,
                color: kContabilidadGlow,
                onTap: () => onUpdateReviewDraft(
                  row!,
                  (current) => current.copyWith(
                    treatment: _ReviewTreatment.internal,
                    clearFamily: true,
                  ),
                ),
              ),
              _DecisionOptionChip(
                label: 'Pasivo / capital',
                active:
                    currentDraft.treatment == _ReviewTreatment.liabilityCapital,
                color: const Color(0xFFFFD58A),
                onTap: () => onUpdateReviewDraft(
                  row!,
                  (current) => current.copyWith(
                    treatment: _ReviewTreatment.liabilityCapital,
                    clearFamily: true,
                  ),
                ),
              ),
              _DecisionOptionChip(
                label: 'Ajuste',
                active: currentDraft.treatment == _ReviewTreatment.adjustment,
                color: const Color(0xFFFFD58A),
                onTap: () => onUpdateReviewDraft(
                  row!,
                  (current) => current.copyWith(
                    treatment: _ReviewTreatment.adjustment,
                    clearFamily: true,
                  ),
                ),
              ),
              _DecisionOptionChip(
                label: 'Fuera de periodo',
                active: currentDraft.treatment == _ReviewTreatment.outOfPeriod,
                color: Colors.white,
                onTap: () => onUpdateReviewDraft(
                  row!,
                  (current) => current.copyWith(
                    treatment: _ReviewTreatment.outOfPeriod,
                    clearFamily: true,
                  ),
                ),
              ),
            ],
          ),
          if (currentDraft.treatment == _ReviewTreatment.expense) ...[
            const SizedBox(height: 16),
            const Text(
              'FAMILIA CONTABLE FINAL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final family in _ReviewExpenseFamily.values)
                  _DecisionOptionChip(
                    label: _expenseFamilyLabel(family),
                    active: currentDraft.family == family,
                    color: kContabilidadSuccess,
                    onTap: () => onUpdateReviewDraft(
                      row!,
                      (current) => current.copyWith(family: family),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'COMENTARIO CONTABLE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: currentDraft.comment,
            minLines: 2,
            maxLines: 4,
            onChanged: (value) => onUpdateReviewDraft(
              row!,
              (current) => current.copyWith(comment: value),
            ),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText:
                  'Ejemplo: soporte revisado, corresponde a nómina menor del periodo.',
              hintStyle: const TextStyle(color: kContabilidadSubtleInk),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: kContabilidadGlow.withValues(alpha: 0.32),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ReviewImpactCallout(row: row!, draft: currentDraft, money: money),
          const SizedBox(height: 12),
          const Text(
            'Estas decisiones hoy funcionan como simulación de cierre dentro de la pantalla. El siguiente paso sería persistirlas para que Utilidad y Estado de Resultados las consuman automáticamente.',
            style: TextStyle(
              color: kContabilidadSubtleInk,
              fontSize: 12.6,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewMovementTile extends StatelessWidget {
  final ContabilidadIncomeStatementReviewMovement movement;
  final String Function(num value) money;

  const _ReviewMovementTile({required this.movement, required this.money});

  @override
  Widget build(BuildContext context) {
    final dateLabel = movement.date == null ? null : _shortDate(movement.date!);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  movement.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                money(movement.amount),
                style: const TextStyle(
                  color: Color(0xFFFFD58A),
                  fontSize: 13.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              dateLabel,
              if (movement.subtitle.trim().isNotEmpty) movement.subtitle.trim(),
            ].join(' · '),
            style: const TextStyle(
              color: kContabilidadSubtleInk,
              fontSize: 12.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movement.detail,
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 12.8,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewImpactCallout extends StatelessWidget {
  final ContabilidadIncomeStatementReviewRow row;
  final _ReviewDecisionDraft draft;
  final String Function(num value) money;

  const _ReviewImpactCallout({
    required this.row,
    required this.draft,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final message = switch (draft.treatment) {
      _ReviewTreatment.expense =>
        draft.family == null
            ? 'Esta partida entraría a utilidad, pero todavía falta definir la familia contable.'
            : 'Esta partida entraría a gasto ${_expenseFamilyLabel(draft.family!).toLowerCase()} y bajaría la utilidad del periodo en ${money(row.amount)}.',
      _ReviewTreatment.internal =>
        'Esta partida saldría definitivamente de utilidad como movimiento interno.',
      _ReviewTreatment.liabilityCapital =>
        'Esta partida saldría definitivamente de utilidad como pasivo o capital.',
      _ReviewTreatment.adjustment =>
        'Esta partida seguiría fuera de utilidad hasta que se reclasifique desde ajuste.',
      _ReviewTreatment.outOfPeriod =>
        'Esta partida saldría del corte actual por no corresponder al periodo.',
      null => 'Elige un tratamiento para ver cómo impacta la utilidad.',
    };
    final color = switch (draft.treatment) {
      _ReviewTreatment.expense => kContabilidadSuccess,
      _ReviewTreatment.internal => kContabilidadGlow,
      _ReviewTreatment.liabilityCapital => const Color(0xFFFFD58A),
      _ReviewTreatment.adjustment => const Color(0xFFFFD58A),
      _ReviewTreatment.outOfPeriod => Colors.white,
      null => kContabilidadMutedInk,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color == Colors.white ? Colors.white : color,
                fontSize: 13.2,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final Color accent;

  const _ReviewStatCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 12.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _DecisionBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12.2,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DecisionOptionChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _DecisionOptionChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: active
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: active
                ? color.withValues(alpha: 0.36)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : kContabilidadMutedInk,
            fontSize: 13.1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ReviewDecisionPreview {
  final double resolvedAsExpense;
  final double resolvedOut;
  final double remainingPending;
  final double projectedResult;

  const _ReviewDecisionPreview({
    required this.resolvedAsExpense,
    required this.resolvedOut,
    required this.remainingPending,
    required this.projectedResult,
  });

  factory _ReviewDecisionPreview.fromDrafts({
    required ContabilidadIncomeStatementSnapshot snapshot,
    required List<ContabilidadIncomeStatementReviewRow> rows,
    required Map<String, _ReviewDecisionDraft> drafts,
  }) {
    var resolvedAsExpense = 0.0;
    var resolvedOut = 0.0;
    for (final row in rows) {
      final draft = drafts[_reviewDecisionKey(row)];
      if (draft == null || !draft.isComplete) continue;
      if (draft.treatment == _ReviewTreatment.expense) {
        resolvedAsExpense += row.amount;
      } else {
        resolvedOut += row.amount;
      }
    }
    final remainingPending =
        (snapshot.reviewPending - resolvedAsExpense - resolvedOut).clamp(
          0.0,
          double.infinity,
        );
    return _ReviewDecisionPreview(
      resolvedAsExpense: resolvedAsExpense,
      resolvedOut: resolvedOut,
      remainingPending: remainingPending,
      projectedResult: snapshot.periodResult - resolvedAsExpense,
    );
  }
}

String _reviewDecisionKey(ContabilidadIncomeStatementReviewRow row) {
  return '${row.sourceLabel}|${row.label}|${row.reason}|${row.suggestedTreatment}';
}

String _reviewStatusLabel(_ReviewDecisionDraft? draft) {
  if (draft == null || draft.treatment == null) return 'Pendiente';
  if (!draft.isComplete) return 'Incompleto';
  return 'Resuelto en sesión';
}

Color _reviewStatusColor(_ReviewDecisionDraft? draft) {
  if (draft == null || draft.treatment == null) {
    return const Color(0xFFFFD58A);
  }
  if (!draft.isComplete) return const Color(0xFFFFD58A);
  return kContabilidadSuccess;
}

String _expenseFamilyLabel(_ReviewExpenseFamily family) {
  return switch (family) {
    _ReviewExpenseFamily.operating => 'Operativo',
    _ReviewExpenseFamily.administrative => 'Administrativo',
    _ReviewExpenseFamily.payroll => 'Nómina',
    _ReviewExpenseFamily.financial => 'Financiero',
  };
}

class _IncomeStatementAuditTabView extends StatelessWidget {
  final ContabilidadIncomeStatementDataset dataset;
  final String Function(num value) money;

  const _IncomeStatementAuditTabView({
    required this.dataset,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AuditSourcesMatrix(rows: dataset.sourceRows, money: money),
        const SizedBox(height: 16),
        _AuditFamilyMatrix(rows: dataset.familyRows),
      ],
    );
  }
}

class _AuditSourcesMatrix extends StatelessWidget {
  final List<ContabilidadIncomeStatementSourceRow> rows;
  final String Function(num value) money;

  const _AuditSourcesMatrix({required this.rows, required this.money});

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FUENTES Y COMPOSICIÓN',
            style: TextStyle(
              color: kContabilidadGlow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 14),
          for (final row in rows) ...[
            _AuditSourceRow(row: row, money: money),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _AuditSourceRow extends StatelessWidget {
  final ContabilidadIncomeStatementSourceRow row;
  final String Function(num value) money;

  const _AuditSourceRow({required this.row, required this.money});

  @override
  Widget build(BuildContext context) {
    final total =
        row.recognizedExpenses + row.internalExcluded + row.reviewPending;
    final base = total <= 0.009 ? 1.0 : total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              money(total),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SegmentedBar(
          segments: [
            _BarSegment(
              fraction: row.recognizedExpenses / base,
              color: kContabilidadSuccess,
            ),
            _BarSegment(
              fraction: row.internalExcluded / base,
              color: kContabilidadGlow,
            ),
            _BarSegment(
              fraction: row.reviewPending / base,
              color: const Color(0xFFFFD58A),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _LegendStat(
              label: 'Reconocido',
              value: money(row.recognizedExpenses),
              color: kContabilidadSuccess,
            ),
            _LegendStat(
              label: 'Interno',
              value: money(row.internalExcluded),
              color: kContabilidadGlow,
            ),
            _LegendStat(
              label: 'Revisión',
              value: money(row.reviewPending),
              color: const Color(0xFFFFD58A),
            ),
          ],
        ),
      ],
    );
  }
}

class _AuditFamilyMatrix extends StatelessWidget {
  final List<ContabilidadAccountingFamilyDefinition> rows;

  const _AuditFamilyMatrix({required this.rows});

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MAPA CONTABLE MAESTRO',
            style: TextStyle(
              color: kContabilidadGlow,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 14),
          for (final row in rows) ...[
            _AuditFamilyRow(row: row),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _AuditFamilyRow extends StatelessWidget {
  final ContabilidadAccountingFamilyDefinition row;

  const _AuditFamilyRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _TagWrap(title: 'Bancos', tags: row.bankCategories),
          const SizedBox(height: 8),
          _TagWrap(title: 'Caja/Bóveda', tags: row.cashRubrics),
        ],
      ),
    );
  }
}

class _TagWrap extends StatelessWidget {
  final String title;
  final List<String> tags;

  const _TagWrap({required this.title, required this.tags});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Text(
          '$title:',
          style: const TextStyle(
            color: kContabilidadMutedInk,
            fontSize: 12.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _SimpleTableRow extends StatelessWidget {
  final String leading;
  final String middle;
  final String trailing;

  const _SimpleTableRow({
    required this.leading,
    required this.middle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            leading,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          width: 90,
          child: Text(
            middle,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 12.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 140,
          child: Text(
            trailing,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: kContabilidadGlow,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

String _percentOf(double value, double total) {
  if (total.abs() <= 0.009) return '0.0%';
  return '${((value / total) * 100).toStringAsFixed(1)}%';
}

class _IncomeStatementLoadingState extends StatelessWidget {
  const _IncomeStatementLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: CircularProgressIndicator(color: kContabilidadGlow),
      ),
    );
  }
}

class _IncomeStatementErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _IncomeStatementErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ContractGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No se pudo cargar el estado de resultados.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => unawaited(onRetry()),
              style: FilledButton.styleFrom(
                backgroundColor: kContabilidadGlow,
                foregroundColor: const Color(0xFF082025),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatRangeLabel(DateTimeRange? range) {
  if (range == null) return 'Sin rango';
  return '${_shortDate(range.start)} - ${_shortDate(range.end)}';
}

String _shortDate(DateTime value) {
  const months = <String>[
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${value.day.toString().padLeft(2, '0')} ${months[value.month - 1]}';
}
