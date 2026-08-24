import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_navigation.dart';
import '../shared/app_shell.dart';
import '../shared/archetypes/auxiliary_surfaces/date_picker_surface.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/utils/number_formatters.dart';
import 'contabilidad_area_chrome.dart';
import 'contabilidad_dashboard_page.dart';
import 'contabilidad_flow_analysis_store.dart';
import 'contabilidad_income_statement_page.dart';
import 'contabilidad_pdf_export.dart';
import 'contabilidad_theme.dart';
import 'contabilidad_trade_analysis_page.dart';

class ContabilidadFlowAnalysisPage extends StatefulWidget {
  final bool instantOpen;

  const ContabilidadFlowAnalysisPage({super.key, this.instantOpen = false});

  @override
  State<ContabilidadFlowAnalysisPage> createState() =>
      _ContabilidadFlowAnalysisPageState();
}

class _ContabilidadFlowAnalysisPageState
    extends State<ContabilidadFlowAnalysisPage> {
  final ContabilidadFlowAnalysisStore _store =
      const ContabilidadFlowAnalysisStore();

  bool _menuOpen = false;
  bool _loading = true;
  String? _error;
  int _windowDays = 7;
  int _selectedTab = 0;
  DateTimeRange? _customRange;
  ContabilidadFlowDataset? _dataset;
  ContabilidadFlowDataset? _previousDataset;
  ContabilidadPeriodicFlowDataset? _periodicDataset;
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
        _store.loadPeriodic(windowDays: _windowDays, dateRange: _customRange),
        _store.loadPeriodicIncome(
          windowDays: _windowDays,
          dateRange: _customRange,
        ),
        _store.loadPeriodicOperational(
          windowDays: _windowDays,
          dateRange: _customRange,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _dataset = results[0] as ContabilidadFlowDataset;
        _previousDataset = results[1] as ContabilidadFlowDataset;
        _periodicDataset = results[2] as ContabilidadPeriodicFlowDataset;
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
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ContabilidadDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openTradeBalance() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const ContabilidadTradeAnalysisPage(instantOpen: true),
      ),
    );
  }

  Future<void> _openFlow() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const ContabilidadFlowAnalysisPage(instantOpen: true)),
    );
  }

  Future<void> _openIncomeStatement() async {
    if (!mounted) return;
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
    final flow = _dataset;
    final payables = _periodicDataset;
    final income = _periodicIncomeDataset;
    final operational = _periodicOperationalDataset;
    if (flow == null ||
        payables == null ||
        income == null ||
        operational == null) {
      return;
    }
    await exportContabilidadFlowPdf(
      flow: flow,
      payables: payables,
      income: income,
      operational: operational,
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

  String _flowConclusion(ContabilidadFlowSnapshot snapshot) {
    final bank = snapshot.bankNetFlow;
    final cash = snapshot.cashNetFlow;
    final net = snapshot.realNetFlow;
    if (cash > 0.009 && bank < -0.009) {
      return 'La caja ayudó a compensar lo que salió de bancos en este periodo.';
    }
    if (bank > 0.009 && cash < -0.009) {
      return 'Los bancos sostuvieron la operación mientras la caja se apretó.';
    }
    if (bank < -0.009 && cash < -0.009) {
      return 'Salió más dinero del que entró tanto en bancos como en caja.';
    }
    if (bank > 0.009 && cash > 0.009) {
      return 'Entró más dinero del que salió tanto en bancos como en caja.';
    }
    if (net > 0.009) {
      return 'En este periodo entró más dinero real del que salió.';
    }
    if (net < -0.009) {
      return 'En este periodo salió más dinero real del que entró.';
    }
    return 'En este periodo el dinero quedó casi parejo entre entradas y salidas.';
  }

  String _flowProposal(ContabilidadFlowSnapshot snapshot) {
    final bank = snapshot.bankNetFlow;
    final cash = snapshot.cashNetFlow;
    final net = snapshot.realNetFlow;
    if (cash > 0.009 && bank < -0.009) {
      return 'Conviene revisar bancos primero: cobrar más rápido, ordenar pagos y detectar qué cargos están jalando más dinero.';
    }
    if (bank > 0.009 && cash < -0.009) {
      return 'Conviene cuidar la caja diaria: revisar salidas de efectivo, fondeo a menudeo y gastos pequeños que se repiten.';
    }
    if (bank < -0.009 && cash < -0.009) {
      return 'Hace falta apretarnos: revisar pagos no urgentes, priorizar cobro y separar qué sí era necesario pagar y qué puede esperar.';
    }
    if (bank > 0.009 && cash > 0.009) {
      return 'Hay margen para ordenar un colchón de efectivo y confirmar si esta mejora se sostiene en el siguiente corte.';
    }
    if (net < -0.009) {
      return 'Conviene revisar rápido por dónde está saliendo más dinero del que entra y decidir si el ajuste debe hacerse en bancos, en caja o en ambos.';
    }
    return 'Basta con seguirlo de cerca para confirmar si el siguiente periodo mejora o si todo sigue parejo.';
  }

  List<String> _plainLanguageRules() {
    return const <String>[
      'Saldo en banco no es lo mismo que flujo. El saldo dice cuánto dinero tienes; el flujo dice si en el periodo entró más o salió más.',
      'Si el flujo sale negativo, no significa automáticamente que la empresa esté mal. Solo significa que en esa ventana salió más dinero del que entró.',
      'Un préstamo puede subir el dinero en la cuenta y aun así no mejorar este indicador si se registró como fondeo interno y no como ingreso operativo.',
      'Movimientos internos son traspasos dentro de la empresa. Se muestran aparte para no inflar entradas o salidas reales.',
    ];
  }

  Color _netColor(double value) {
    if (value > 0.009) return kContabilidadSuccess;
    if (value < -0.009) return const Color(0xFFFF8A80);
    return kContabilidadGlow;
  }

  String _statusLabel(ContabilidadFlowSnapshot snapshot) {
    if (snapshot.realNetFlow > 0.009 &&
        snapshot.bankNetFlow >= -0.009 &&
        snapshot.cashNetFlow >= -0.009) {
      return 'Excelente';
    }
    if (snapshot.realNetFlow < -0.009 ||
        (snapshot.bankNetFlow < -0.009 && snapshot.cashNetFlow < -0.009)) {
      return 'Riesgo';
    }
    return 'Atención';
  }

  Color _statusColor(ContabilidadFlowSnapshot snapshot) {
    return switch (_statusLabel(snapshot)) {
      'Excelente' => kContabilidadSuccess,
      'Riesgo' => const Color(0xFFFF8A80),
      _ => const Color(0xFFFFD58A),
    };
  }

  IconData _statusIcon(ContabilidadFlowSnapshot snapshot) {
    return switch (_statusLabel(snapshot)) {
      'Excelente' => Icons.check_circle_rounded,
      'Riesgo' => Icons.warning_amber_rounded,
      _ => Icons.visibility_rounded,
    };
  }

  double? _changePercent(double current, double previous) {
    if (previous.abs() <= 0.009) return null;
    return ((current - previous) / previous.abs()) * 100;
  }

  String _changeLabel(double current, double previous) {
    final percent = _changePercent(current, previous);
    if (percent == null) return 'Sin base comparable';
    final arrow = percent >= 0 ? '↑' : '↓';
    return '$arrow ${percent.abs().toStringAsFixed(0)}% vs periodo anterior';
  }

  List<({String text, Color tone})> _buildInsights(
    ContabilidadFlowDataset current,
    ContabilidadFlowDataset? previous,
  ) {
    final snapshot = current.snapshot;
    final insights = <({String text, Color tone})>[];
    insights.add((
      text: snapshot.realNetFlow >= 0
          ? 'El flujo del periodo fue positivo.'
          : 'El flujo del periodo fue negativo.',
      tone: snapshot.realNetFlow >= 0
          ? kContabilidadSuccess
          : const Color(0xFFFF8A80),
    ));
    if (snapshot.cashNetFlow > 0.009 && snapshot.bankNetFlow < -0.009) {
      insights.add((
        text: 'El efectivo compensó la presión en bancos.',
        tone: const Color(0xFFFFD58A),
      ));
    }
    if (snapshot.bankNetFlow < -0.009) {
      insights.add((
        text: 'Bancos cerraron negativos en el periodo.',
        tone: const Color(0xFFFF8A80),
      ));
    }
    if (snapshot.cashNetFlow < -0.009) {
      insights.add((
        text: 'Menudeo y bóveda consumieron efectivo neto.',
        tone: const Color(0xFFFFD58A),
      ));
    }
    final topOutflow = <ContabilidadFlowBreakdownRow>[
      ...current.bankCategoryRows.take(3),
      ...current.cashRubricRows.take(3),
    ]..sort((a, b) => b.total.compareTo(a.total));
    if (topOutflow.isNotEmpty) {
      insights.add((
        text:
            'El mayor egreso visible fue ${topOutflow.first.label} con ${_money(topOutflow.first.total)}.',
        tone: kContabilidadGlow,
      ));
    }
    final previousSnapshot = previous?.snapshot;
    if (previousSnapshot != null) {
      final flowChange = _changePercent(
        snapshot.realNetFlow,
        previousSnapshot.realNetFlow,
      );
      if (flowChange != null) {
        insights.add((
          text: flowChange >= 0
              ? 'El flujo mejoró ${flowChange.abs().toStringAsFixed(0)}% contra el periodo anterior.'
              : 'El flujo cayó ${flowChange.abs().toStringAsFixed(0)}% contra el periodo anterior.',
          tone: flowChange >= 0
              ? kContabilidadSuccess
              : const Color(0xFFFFD58A),
        ));
      }
    }
    return insights.take(6).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final dataset = _dataset;
    final previousDataset = _previousDataset;
    final currentRangeLabel = _rangeLabel();
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
            title: 'Análisis de Flujo',
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
                          _FlowToolbar(
                            selectedRangeDays: _customRange == null
                                ? _windowDays
                                : null,
                            rangeLabel: currentRangeLabel,
                            onSetLast7Days: () => _setWindowDays(7),
                            onSetLast30Days: () => _setWindowDays(30),
                            onSetLast90Days: () => _setWindowDays(90),
                            onPickDateRange: _pickCustomRange,
                          ),
                          const SizedBox(height: 14),
                          _FlowAnalysisTabs(
                            selectedIndex: _selectedTab,
                            onChanged: (value) {
                              setState(() => _selectedTab = value);
                            },
                          ),
                          const SizedBox(height: 14),
                          if (_loading)
                            const _FlowLoadingState()
                          else if (_error != null)
                            _FlowErrorState(message: _error!, onRetry: _load)
                          else if (_selectedTab == 1 &&
                              _periodicDataset != null)
                            _PeriodicFlowPanel(
                              dataset: _periodicDataset!,
                              incomeDataset: _periodicIncomeDataset,
                              operationalDataset: _periodicOperationalDataset,
                              money: _money,
                              shortDate: _shortDate,
                            )
                          else if (dataset != null) ...[
                            _FlowStatusHeroPanel(
                              snapshot: dataset.snapshot,
                              previousSnapshot: previousDataset?.snapshot,
                              rangeLabel: currentRangeLabel,
                              money: _money,
                              changeLabel: _changeLabel,
                              statusLabel: _statusLabel(dataset.snapshot),
                              statusIcon: _statusIcon(dataset.snapshot),
                              statusColor: _statusColor(dataset.snapshot),
                            ),
                            const SizedBox(height: 14),
                            _FlowPlainLanguagePanel(
                              rules: _plainLanguageRules(),
                            ),
                            const SizedBox(height: 14),
                            _FlowAuditPanel(
                              auditNotes: dataset.auditNotes,
                              notes: dataset.notes,
                            ),
                            const SizedBox(height: 14),
                            _FlowInsightsPanel(
                              insights: _buildInsights(
                                dataset,
                                previousDataset,
                              ),
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 1180;
                                if (compact) {
                                  return Column(
                                    children: [
                                      _FlowConclusionPanel(
                                        conclusion: _flowConclusion(
                                          dataset.snapshot,
                                        ),
                                        proposal: _flowProposal(
                                          dataset.snapshot,
                                        ),
                                        accent: _netColor(
                                          dataset.snapshot.realNetFlow,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _FlowContributionPanel(
                                        dataset: dataset,
                                        money: _money,
                                      ),
                                      const SizedBox(height: 14),
                                      _FlowOutflowsPanel(
                                        bankRows: dataset.bankCategoryRows,
                                        cashRows: dataset.cashRubricRows,
                                        money: _money,
                                      ),
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 7,
                                      child: Column(
                                        children: [
                                          _FlowConclusionPanel(
                                            conclusion: _flowConclusion(
                                              dataset.snapshot,
                                            ),
                                            proposal: _flowProposal(
                                              dataset.snapshot,
                                            ),
                                            accent: _netColor(
                                              dataset.snapshot.realNetFlow,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          _FlowContributionPanel(
                                            dataset: dataset,
                                            money: _money,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      flex: 4,
                                      child: _FlowOutflowsPanel(
                                        bankRows: dataset.bankCategoryRows,
                                        cashRows: dataset.cashRubricRows,
                                        money: _money,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 1180;
                                if (compact) {
                                  return Column(
                                    children: [
                                      _FlowTimelinePanel(
                                        points: dataset.timeline,
                                        money: _money,
                                        shortDate: _shortDate,
                                        netColor: _netColor,
                                      ),
                                      const SizedBox(height: 14),
                                      _FlowFormulaPanel(
                                        dataset: dataset,
                                        money: _money,
                                      ),
                                    ],
                                  );
                                }
                                return Column(
                                  children: [
                                    _FlowTimelinePanel(
                                      points: dataset.timeline,
                                      money: _money,
                                      shortDate: _shortDate,
                                      netColor: _netColor,
                                    ),
                                    const SizedBox(height: 14),
                                    _FlowFormulaPanel(
                                      dataset: dataset,
                                      money: _money,
                                    ),
                                  ],
                                );
                              },
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
                      current: ContabilidadAreaScreen.flujoGeneral,
                      onOpenTradeBalance: _openTradeBalance,
                      onOpenFlujoGeneral: _openFlow,
                      onOpenEstadoResultados: _openIncomeStatement,
                    ),
                    accessItems: buildContabilidadAccessItems(
                      current: ContabilidadAreaScreen.flujoGeneral,
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

class _FlowToolbar extends StatelessWidget {
  final int? selectedRangeDays;
  final String rangeLabel;
  final VoidCallback onSetLast7Days;
  final VoidCallback onSetLast30Days;
  final VoidCallback onSetLast90Days;
  final Future<void> Function() onPickDateRange;

  const _FlowToolbar({
    required this.selectedRangeDays,
    required this.rangeLabel,
    required this.onSetLast7Days,
    required this.onSetLast30Days,
    required this.onSetLast90Days,
    required this.onPickDateRange,
  });

  @override
  Widget build(BuildContext context) {
    return ContabilidadToolbarPanel(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Propuesta de lectura ejecutiva',
                style: TextStyle(
                  color: kContabilidadInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _FlowFilterChipButton(
                label: '7d',
                selected: selectedRangeDays == 7,
                onTap: onSetLast7Days,
              ),
              _FlowFilterChipButton(
                label: '30d',
                selected: selectedRangeDays == 30,
                onTap: onSetLast30Days,
              ),
              _FlowFilterChipButton(
                label: '90d',
                selected: selectedRangeDays == 90,
                onTap: onSetLast90Days,
              ),
              ContabilidadPageHeaderButton(
                label: rangeLabel,
                icon: Icons.date_range_rounded,
                width: 186,
                onTap: onPickDateRange,
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: const Text(
              'Bóveda + Menudeo + Bancos',
              style: TextStyle(
                color: kContabilidadMutedInk,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowFilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FlowFilterChipButton({
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
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected ? kContabilidadSelectionGradient : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 0.24 : 0.10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : kContabilidadMutedInk,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _FlowAnalysisTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _FlowAnalysisTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ContabilidadGlassPanel(
      padding: const EdgeInsets.all(6),
      borderRadius: BorderRadius.circular(18),
      blurSigma: 22,
      fillColor: kContabilidadSurface.withValues(alpha: 0.88),
      borderColor: Colors.white.withValues(alpha: 0.15),
      shadowColor: Colors.black.withValues(alpha: 0.10),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.44),
      bevelShadowColor: Colors.black.withValues(alpha: 0.14),
      glowColor: kContabilidadGlow.withValues(alpha: 0.08),
      child: Row(
        children: [
          _FlowTabButton(
            label: 'Flujo real',
            detail: 'Bancos, caja y bóveda',
            icon: Icons.account_balance_wallet_rounded,
            selected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
          const SizedBox(width: 6),
          _FlowTabButton(
            label: 'Facturas del periodo',
            detail: 'Facturado vs. pagado',
            icon: Icons.receipt_long_rounded,
            selected: selectedIndex == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _FlowTabButton extends StatelessWidget {
  final String label;
  final String detail;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FlowTabButton({
    required this.label,
    required this.detail,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: selected ? kContabilidadSelectionGradient : null,
            border: Border.all(
              color: Colors.white.withValues(alpha: selected ? 0.22 : 0.04),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : kContabilidadMutedInk,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : kContabilidadInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.78)
                            : kContabilidadMutedInk,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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

class _PeriodicFlowPanel extends StatelessWidget {
  final ContabilidadPeriodicFlowDataset dataset;
  final ContabilidadPeriodicIncomeDataset? incomeDataset;
  final ContabilidadPeriodicOperationalDataset? operationalDataset;
  final String Function(num value) money;
  final String Function(DateTime value) shortDate;

  const _PeriodicFlowPanel({
    required this.dataset,
    required this.incomeDataset,
    required this.operationalDataset,
    required this.money,
    required this.shortDate,
  });

  @override
  Widget build(BuildContext context) {
    final hasRows = dataset.rows.isNotEmpty;
    final paidTone = dataset.periodNet >= 0
        ? kContabilidadSuccess
        : const Color(0xFFFFB36B);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContabilidadGlassPanel(
          padding: const EdgeInsets.all(22),
          borderRadius: BorderRadius.circular(24),
          blurSigma: 26,
          fillColor: kContabilidadSurface.withValues(alpha: 0.94),
          borderColor: Colors.white.withValues(alpha: 0.17),
          shadowColor: Colors.black.withValues(alpha: 0.12),
          edgeHighlightColor: Colors.white.withValues(alpha: 0.52),
          bevelShadowColor: Colors.black.withValues(alpha: 0.16),
          glowColor: paidTone.withValues(alpha: 0.12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lo que nació y se pagó en este periodo',
                style: TextStyle(
                  color: kContabilidadInk,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sólo considera facturas fechadas dentro del rango. Los pagos de facturas de meses anteriores no entran aquí.',
                style: TextStyle(
                  color: kContabilidadMutedInk,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _PeriodicMetric(
                    label: 'Facturado en el periodo',
                    value: money(dataset.invoicedAmount),
                    detail: '${dataset.invoiceCount} facturas registradas',
                    color: kContabilidadGlow,
                  ),
                  _PeriodicMetric(
                    label: 'Pagado de esas facturas',
                    value: money(dataset.paidAmount),
                    detail: 'Salidas vinculadas a la factura',
                    color: paidTone,
                  ),
                  _PeriodicMetric(
                    label: 'Pendiente de esas facturas',
                    value: money(dataset.pendingAmount),
                    detail: '${dataset.pendingInvoiceCount} facturas con saldo',
                    color: const Color(0xFFFFB36B),
                  ),
                ],
              ),
              if (incomeDataset != null) ...[
                const SizedBox(height: 18),
                _PeriodicIncomeSummary(dataset: incomeDataset!, money: money),
              ],
              if (operationalDataset != null) ...[
                const SizedBox(height: 14),
                _PeriodicOperationalSummary(
                  dataset: operationalDataset!,
                  money: money,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 860;
            final paymentReading = _PeriodicPaymentReading(
              onTimeAmount: dataset.paidOnTimeAmount,
              lateAmount: dataset.paidLateAmount,
              money: money,
            );
            final trustReading = _PeriodicTrustReading(
              unlinkedPaymentCount: dataset.unlinkedPaymentCount,
              paidHistoricalOverdueAmount: dataset.paidHistoricalOverdueAmount,
              paidHistoricalOverdueCount: dataset.paidHistoricalOverdueCount,
              money: money,
            );
            if (compact) {
              return Column(
                children: [
                  paymentReading,
                  const SizedBox(height: 14),
                  trustReading,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: paymentReading),
                const SizedBox(width: 14),
                Expanded(flex: 5, child: trustReading),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        ContabilidadGlassPanel(
          padding: const EdgeInsets.all(20),
          borderRadius: BorderRadius.circular(24),
          blurSigma: 24,
          fillColor: kContabilidadSurface.withValues(alpha: 0.90),
          borderColor: Colors.white.withValues(alpha: 0.16),
          shadowColor: Colors.black.withValues(alpha: 0.10),
          edgeHighlightColor: Colors.white.withValues(alpha: 0.46),
          bevelShadowColor: Colors.black.withValues(alpha: 0.15),
          glowColor: kContabilidadGlow.withValues(alpha: 0.08),
          child: !hasRows
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'No hay facturas registradas dentro de este periodo.',
                      style: TextStyle(
                        color: kContabilidadMutedInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detalle de facturas del periodo',
                      style: TextStyle(
                        color: kContabilidadInk,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'El pago se marca tarde sólo si ocurrió después de la fecha de vencimiento de esa factura.',
                      style: TextStyle(
                        color: kContabilidadMutedInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...dataset.rows.map(
                      (row) => _PeriodicInvoiceRow(
                        row: row,
                        money: money,
                        shortDate: shortDate,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PeriodicOperationalSummary extends StatelessWidget {
  final ContabilidadPeriodicOperationalDataset dataset;
  final String Function(num value) money;

  const _PeriodicOperationalSummary({
    required this.dataset,
    required this.money,
  });

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
            'Movimientos fechados dentro del rango; reposiciones y traspasos de Bóveda se dejan fuera del resultado.',
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
            'Bóveda: ${money(dataset.vaultInflows)} entra / ${money(dataset.vaultOutflows)} sale · Efectivo: ${money(dataset.cashInflows)} entra / ${money(dataset.cashOutflows)} sale${dataset.vaultInternalTransfers > 0.009 ? ' · Internos aislados ${money(dataset.vaultInternalTransfers)}' : ''}',
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodicIncomeSummary extends StatelessWidget {
  final ContabilidadPeriodicIncomeDataset dataset;
  final String Function(num value) money;

  const _PeriodicIncomeSummary({required this.dataset, required this.money});

  @override
  Widget build(BuildContext context) {
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
            'Se cuentan sólo cobros bancarios vinculados a la factura de venta.',
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
          if (dataset.collectedHistoricalOverdueAmount > 0.009 ||
              dataset.unlinkedCollectionCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              _contextLabel(),
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

  String _contextLabel() {
    final messages = <String>[];
    if (dataset.collectedHistoricalOverdueAmount > 0.009) {
      messages.add(
        'Cobros de atrasos anteriores: ${money(dataset.collectedHistoricalOverdueAmount)}; no se mezclan con este periodo.',
      );
    }
    if (dataset.unlinkedCollectionCount > 0) {
      messages.add(
        '${dataset.unlinkedCollectionCount} cobro(s) sin vínculo a una factura no se incluyeron.',
      );
    }
    return messages.join(' ');
  }
}

class _PeriodicMetric extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final Color color;

  const _PeriodicMetric({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.23)),
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

class _PeriodicPaymentReading extends StatelessWidget {
  final double onTimeAmount;
  final double lateAmount;
  final String Function(num value) money;

  const _PeriodicPaymentReading({
    required this.onTimeAmount,
    required this.lateAmount,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    return _PeriodicInfoCard(
      icon: Icons.schedule_rounded,
      title: 'Cómo se pagaron',
      child: Column(
        children: [
          _PeriodicAmountLine(
            label: 'Pagado a tiempo o antes de vencer',
            value: money(onTimeAmount),
            color: kContabilidadSuccess,
          ),
          const SizedBox(height: 10),
          _PeriodicAmountLine(
            label: 'Pagado después de vencer',
            value: money(lateAmount),
            color: const Color(0xFFFFB36B),
          ),
        ],
      ),
    );
  }
}

class _PeriodicTrustReading extends StatelessWidget {
  final int unlinkedPaymentCount;
  final double paidHistoricalOverdueAmount;
  final int paidHistoricalOverdueCount;
  final String Function(num value) money;

  const _PeriodicTrustReading({
    required this.unlinkedPaymentCount,
    required this.paidHistoricalOverdueAmount,
    required this.paidHistoricalOverdueCount,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnlinked = unlinkedPaymentCount > 0;
    return _PeriodicInfoCard(
      icon: hasUnlinked ? Icons.link_off_rounded : Icons.verified_rounded,
      title: hasUnlinked ? 'Dato por completar' : 'Lectura verificable',
      iconColor: hasUnlinked ? const Color(0xFFFFB36B) : kContabilidadSuccess,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasUnlinked
                ? 'Hay $unlinkedPaymentCount pagos de factura sin vínculo a una factura. No se sumaron aquí para no atribuirlos mal.'
                : 'Cada pago incluido tiene vínculo explícito con una factura del periodo. Puedes rastrearlo desde la cuenta por pagar.',
            style: const TextStyle(
              color: kContabilidadMutedInk,
              height: 1.35,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (paidHistoricalOverdueAmount > 0.009) ...[
            const SizedBox(height: 12),
            Text(
              'Aparte se pagaron ${money(paidHistoricalOverdueAmount)} de $paidHistoricalOverdueCount factura(s) vencida(s) de periodos anteriores. No altera la lectura del periodo.',
              style: const TextStyle(
                color: Color(0xFFFFD08A),
                height: 1.35,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PeriodicInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Color? iconColor;

  const _PeriodicInfoCard({
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final tone = iconColor ?? kContabilidadGlow;
    return ContabilidadGlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: BorderRadius.circular(20),
      blurSigma: 22,
      fillColor: kContabilidadSurface.withValues(alpha: 0.90),
      borderColor: Colors.white.withValues(alpha: 0.15),
      shadowColor: Colors.black.withValues(alpha: 0.09),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.43),
      bevelShadowColor: Colors.black.withValues(alpha: 0.14),
      glowColor: tone.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: tone, size: 20),
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

class _PeriodicAmountLine extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PeriodicAmountLine({
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

class _PeriodicInvoiceRow extends StatelessWidget {
  final ContabilidadPeriodicFlowRow row;
  final String Function(num value) money;
  final String Function(DateTime value) shortDate;

  const _PeriodicInvoiceRow({
    required this.row,
    required this.money,
    required this.shortDate,
  });

  @override
  Widget build(BuildContext context) {
    final status = row.pendingAmount > 0.009
        ? 'Pendiente ${money(row.pendingAmount)}'
        : row.hasLatePayment
        ? 'Pagada tarde'
        : 'Pagada a tiempo';
    final tone = row.pendingAmount > 0.009
        ? const Color(0xFFFFB36B)
        : row.hasLatePayment
        ? const Color(0xFFFFB36B)
        : kContabilidadSuccess;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 250,
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
            'Facturada ${shortDate(row.invoiceDate)}',
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            row.dueDate == null
                ? 'Sin vencimiento'
                : 'Vence ${shortDate(row.dueDate!)}',
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 12,
              fontWeight: FontWeight.w600,
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

class _FlowLoadingState extends StatelessWidget {
  const _FlowLoadingState();

  @override
  Widget build(BuildContext context) {
    return ContabilidadGlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(24),
      blurSigma: 24,
      fillColor: kContabilidadSurface.withValues(alpha: 0.88),
      borderColor: Colors.white.withValues(alpha: 0.18),
      shadowColor: Colors.black.withValues(alpha: 0.10),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.54),
      bevelShadowColor: Colors.black.withValues(alpha: 0.16),
      glowColor: kContabilidadGlow.withValues(alpha: 0.10),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Cargando flujo consolidado desde bancos, bóveda y menudeo...',
              style: TextStyle(
                color: kContabilidadInk,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _FlowErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ContabilidadGlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(24),
      blurSigma: 24,
      fillColor: const Color(0xCC3A1717),
      borderColor: Colors.white.withValues(alpha: 0.14),
      shadowColor: Colors.black.withValues(alpha: 0.12),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.36),
      bevelShadowColor: Colors.black.withValues(alpha: 0.16),
      glowColor: const Color(0x66FF8A80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No se pudo cargar el análisis de flujo.',
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
              color: Color(0xFFE7C5C5),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => unawaited(onRetry()),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _FlowStatusHeroPanel extends StatelessWidget {
  final ContabilidadFlowSnapshot snapshot;
  final ContabilidadFlowSnapshot? previousSnapshot;
  final String rangeLabel;
  final String Function(num) money;
  final String Function(double current, double previous) changeLabel;
  final String statusLabel;
  final IconData statusIcon;
  final Color statusColor;

  const _FlowStatusHeroPanel({
    required this.snapshot,
    required this.previousSnapshot,
    required this.rangeLabel,
    required this.money,
    required this.changeLabel,
    required this.statusLabel,
    required this.statusIcon,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final previousNet = previousSnapshot?.realNetFlow;
    final comparison = previousNet == null
        ? 'Sin comparación anterior'
        : changeLabel(snapshot.realNetFlow, previousNet);
    return ContabilidadGlassPanel(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(26),
      blurSigma: 24,
      fillColor: kContabilidadSurface.withValues(alpha: 0.90),
      borderColor: Colors.white.withValues(alpha: 0.18),
      shadowColor: Colors.black.withValues(alpha: 0.10),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.54),
      bevelShadowColor: Colors.black.withValues(alpha: 0.16),
      glowColor: statusColor.withValues(alpha: 0.12),
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
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 18, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                rangeLabel.toUpperCase(),
                style: const TextStyle(
                  color: kContabilidadMutedInk,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Flujo Neto',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            money(snapshot.realNetFlow),
            style: TextStyle(
              color: statusColor,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              height: 0.98,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            comparison,
            style: const TextStyle(
              color: kContabilidadMutedInk,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ContabilidadMetricCard(
                icon: Icons.arrow_downward_rounded,
                title: 'ENTRÓ',
                value: money(snapshot.realInflows),
                detail: 'Dinero real que sí entró',
                accent: kContabilidadSuccess,
                width: 250,
              ),
              ContabilidadMetricCard(
                icon: Icons.arrow_upward_rounded,
                title: 'SALIÓ',
                value: money(snapshot.realOutflows),
                detail: 'Dinero real que sí salió',
                accent: const Color(0xFFFFB37C),
                width: 250,
              ),
              ContabilidadMetricCard(
                icon: Icons.swap_horiz_rounded,
                title: 'INTERNOS',
                value: money(snapshot.internalTransfers),
                detail: 'No cuentan como gasto real',
                accent: kContabilidadGlow,
                width: 250,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _LiquidityPill(
                    title: 'Liquidez · Efectivo',
                    value: money(snapshot.cashNetFlow),
                    accent: snapshot.cashNetFlow >= 0
                        ? kContabilidadSuccess
                        : const Color(0xFFFF8A80),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LiquidityPill(
                    title: 'Liquidez · Bancos',
                    value: money(snapshot.bankNetFlow),
                    accent: snapshot.bankNetFlow >= 0
                        ? kContabilidadSuccess
                        : const Color(0xFFFF8A80),
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

class _LiquidityPill extends StatelessWidget {
  final String title;
  final String value;
  final Color accent;

  const _LiquidityPill({
    required this.title,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowInsightsPanel extends StatelessWidget {
  final List<({String text, Color tone})> insights;

  const _FlowInsightsPanel({required this.insights});

  @override
  Widget build(BuildContext context) {
    return ContabilidadGlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      blurSigma: 24,
      fillColor: kContabilidadSurface.withValues(alpha: 0.88),
      borderColor: Colors.white.withValues(alpha: 0.18),
      shadowColor: Colors.black.withValues(alpha: 0.10),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.54),
      bevelShadowColor: Colors.black.withValues(alpha: 0.16),
      glowColor: kContabilidadGlow.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lectura rápida del periodo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (final insight in insights) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, size: 10, color: insight.tone),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    insight.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            if (insight != insights.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _FlowPlainLanguagePanel extends StatelessWidget {
  final List<String> rules;

  const _FlowPlainLanguagePanel({required this.rules});

  @override
  Widget build(BuildContext context) {
    return ContabilidadGlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      blurSigma: 24,
      fillColor: kContabilidadSurface.withValues(alpha: 0.88),
      borderColor: Colors.white.withValues(alpha: 0.18),
      shadowColor: Colors.black.withValues(alpha: 0.10),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.54),
      bevelShadowColor: Colors.black.withValues(alpha: 0.16),
      glowColor: kContabilidadSuccess.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cómo leer esta pantalla',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Guía rápida para leer el resultado sin necesitar lenguaje contable.',
            style: TextStyle(
              color: kContabilidadMutedInk,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          for (final rule in rules) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.lightbulb_rounded,
                      color: kContabilidadSuccess,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rule,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (rule != rules.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _FlowAuditPanel extends StatelessWidget {
  final List<ContabilidadFlowAuditNote> auditNotes;
  final List<String> notes;

  const _FlowAuditPanel({required this.auditNotes, required this.notes});

  Color _tone(ContabilidadFlowAuditLevel level) {
    return switch (level) {
      ContabilidadFlowAuditLevel.ok => kContabilidadSuccess,
      ContabilidadFlowAuditLevel.warning => const Color(0xFFFFD58A),
      ContabilidadFlowAuditLevel.risk => const Color(0xFFFF8A80),
    };
  }

  IconData _icon(ContabilidadFlowAuditLevel level) {
    return switch (level) {
      ContabilidadFlowAuditLevel.ok => Icons.verified_rounded,
      ContabilidadFlowAuditLevel.warning => Icons.visibility_rounded,
      ContabilidadFlowAuditLevel.risk => Icons.warning_amber_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ContabilidadGlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      blurSigma: 24,
      fillColor: kContabilidadSurface.withValues(alpha: 0.88),
      borderColor: Colors.white.withValues(alpha: 0.18),
      shadowColor: Colors.black.withValues(alpha: 0.10),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.54),
      bevelShadowColor: Colors.black.withValues(alpha: 0.16),
      glowColor: kContabilidadGlow.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confiabilidad de la lectura',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Aquí se aclara qué tan firme es la lectura y si hay algo que deba tomarse con cautela.',
            style: TextStyle(
              color: kContabilidadMutedInk,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          for (final note in auditNotes) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_icon(note.level), color: _tone(note.level), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          style: TextStyle(
                            color: _tone(note.level),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          note.detail,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (note != auditNotes.last) const SizedBox(height: 10),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Reglas de lectura',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            for (final line in notes) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(
                      Icons.circle,
                      size: 7,
                      color: kContabilidadMutedInk,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(
                        color: kContabilidadMutedInk,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              if (line != notes.last) const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _FlowConclusionPanel extends StatelessWidget {
  final String conclusion;
  final String proposal;
  final Color accent;

  const _FlowConclusionPanel({
    required this.conclusion,
    required this.proposal,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ContabilidadGlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      blurSigma: 24,
      fillColor: kContabilidadSurface.withValues(alpha: 0.88),
      borderColor: Colors.white.withValues(alpha: 0.18),
      shadowColor: Colors.black.withValues(alpha: 0.10),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.54),
      bevelShadowColor: Colors.black.withValues(alpha: 0.16),
      glowColor: accent.withValues(alpha: 0.10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final conclusionCard = _ConclusionBox(
            title: 'Conclusión',
            body: conclusion,
            accent: accent,
          );
          final proposalCard = _ConclusionBox(
            title: 'Propuesta',
            body: proposal,
            accent: kContabilidadMint,
          );
          if (compact) {
            return Column(
              children: [
                conclusionCard,
                const SizedBox(height: 12),
                proposalCard,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: conclusionCard),
              const SizedBox(width: 12),
              Expanded(child: proposalCard),
            ],
          );
        },
      ),
    );
  }
}

class _ConclusionBox extends StatelessWidget {
  final String title;
  final String body;
  final Color accent;

  const _ConclusionBox({
    required this.title,
    required this.body,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            title.toUpperCase(),
            style: TextStyle(
              color: accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowFormulaPanel extends StatelessWidget {
  final ContabilidadFlowDataset dataset;
  final String Function(num) money;

  const _FlowFormulaPanel({required this.dataset, required this.money});

  ContabilidadFlowSourceRow _source(String label) {
    return dataset.sources.firstWhere(
      (row) => row.label == label,
      orElse: () => const ContabilidadFlowSourceRow(
        label: '',
        detail: '',
        realInflows: 0,
        realOutflows: 0,
        internalTransfers: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bancos = _source('Bancos');
    final boveda = _source('Bóveda');
    final menudeo = _source('Menudeo');
    final snapshot = dataset.snapshot;
    return ContabilidadGlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      blurSigma: 24,
      fillColor: kContabilidadSurface.withValues(alpha: 0.88),
      borderColor: Colors.white.withValues(alpha: 0.18),
      shadowColor: Colors.black.withValues(alpha: 0.10),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.54),
      bevelShadowColor: Colors.black.withValues(alpha: 0.16),
      glowColor: kContabilidadGlow.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cómo se calcula',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Aquí se ve la cuenta exacta de cada número. Sirve para pasar de la lectura simple a la validación detallada.',
            style: TextStyle(
              color: kContabilidadMutedInk,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _FormulaBlock(
            title: 'Dinero que sí entró a la empresa',
            value: money(snapshot.realInflows),
            formula:
                '${money(bancos.realInflows)} + ${money(boveda.realInflows)} + ${money(menudeo.realInflows)}',
            breakdown: [
              'Entró por bancos: ${money(bancos.realInflows)}',
              'Entró por bóveda: ${money(boveda.realInflows)}',
              'Entró por menudeo: ${money(menudeo.realInflows)}',
            ],
          ),
          const SizedBox(height: 12),
          _FormulaBlock(
            title: 'Dinero que sí salió de la empresa',
            value: money(snapshot.realOutflows),
            formula:
                '${money(bancos.realOutflows)} + ${money(boveda.realOutflows)} + ${money(menudeo.realOutflows)}',
            breakdown: [
              'Salió por bancos: ${money(bancos.realOutflows)}',
              'Salió por bóveda: ${money(boveda.realOutflows)}',
              'Salió por menudeo: ${money(menudeo.realOutflows)}',
            ],
          ),
          const SizedBox(height: 12),
          _FormulaBlock(
            title: 'Resultado final del periodo',
            value: money(snapshot.realNetFlow),
            formula:
                '${money(snapshot.realInflows)} - ${money(snapshot.realOutflows)}',
            breakdown: const [
              'Es todo lo que sí entró menos todo lo que sí salió.',
              'Si sale positivo, entró más dinero del que salió en el periodo.',
              'Si sale negativo, salió más dinero del que entró en el periodo.',
              'No es utilidad: sólo es movimiento neto de dinero real.',
            ],
          ),
          const SizedBox(height: 12),
          _FormulaBlock(
            title: 'Dinero que sólo se movió dentro de la empresa',
            value: money(snapshot.internalTransfers),
            formula:
                '${money(bancos.internalTransfers)} + ${money(boveda.internalTransfers)}',
            breakdown: [
              'Movimientos internos en bancos: ${money(bancos.internalTransfers)}',
              'Movimientos internos en bóveda: ${money(boveda.internalTransfers)}',
              'Menudeo no se suma aquí porque ya viene limpio de internos.',
            ],
          ),
          const SizedBox(height: 12),
          _FormulaBlock(
            title: 'Resultado del efectivo',
            value: money(snapshot.cashNetFlow),
            formula:
                '(${money(boveda.realInflows)} + ${money(menudeo.realInflows)}) - (${money(boveda.realOutflows)} + ${money(menudeo.realOutflows)})',
            breakdown: [
              'Entró efectivo a bóveda: ${money(boveda.realInflows)}',
              'Entró efectivo a menudeo: ${money(menudeo.realInflows)}',
              'Salió efectivo de bóveda: ${money(boveda.realOutflows)}',
              'Salió efectivo de menudeo: ${money(menudeo.realOutflows)}',
            ],
          ),
        ],
      ),
    );
  }
}

class _FormulaBlock extends StatelessWidget {
  final String title;
  final String value;
  final String formula;
  final List<String> breakdown;

  const _FormulaBlock({
    required this.title,
    required this.value,
    required this.formula,
    required this.breakdown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                style: const TextStyle(
                  color: kContabilidadMint,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            formula,
            style: const TextStyle(
              color: kContabilidadInk,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          for (final line in breakdown) ...[
            Text(
              line,
              style: const TextStyle(
                color: kContabilidadMutedInk,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            if (line != breakdown.last) const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _FlowContributionPanel extends StatelessWidget {
  final ContabilidadFlowDataset dataset;
  final String Function(num) money;

  const _FlowContributionPanel({required this.dataset, required this.money});

  @override
  Widget build(BuildContext context) {
    final rows = List<ContabilidadFlowSourceRow>.from(dataset.sources)
      ..sort((a, b) => b.netFlow.abs().compareTo(a.netFlow.abs()));
    final maxValue = rows.fold<double>(
      1,
      (max, row) => row.netFlow.abs() > max ? row.netFlow.abs() : max,
    );
    return ContabilidadGlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      blurSigma: 24,
      fillColor: kContabilidadSurface.withValues(alpha: 0.88),
      borderColor: Colors.white.withValues(alpha: 0.18),
      shadowColor: Colors.black.withValues(alpha: 0.10),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.54),
      bevelShadowColor: Colors.black.withValues(alpha: 0.16),
      glowColor: kContabilidadGlow.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Qué área ayudó y cuál presionó',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Comparativo simple para ver dónde entró más dinero del que salió y dónde pasó lo contrario.',
            style: TextStyle(
              color: kContabilidadMutedInk,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          for (final row in rows) ...[
            _ContributionBarRow(
              label: row.label,
              value: row.netFlow,
              maxValue: maxValue,
              money: money,
            ),
            if (row != rows.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ContributionBarRow extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final String Function(num) money;

  const _ContributionBarRow({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final tone = value >= 0 ? kContabilidadSuccess : const Color(0xFFFF8A80);
    final widthFactor = (value.abs() / maxValue).clamp(0.04, 1.0);
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
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              money(value),
              style: TextStyle(color: tone, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: widthFactor,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FlowOutflowsPanel extends StatelessWidget {
  final List<ContabilidadFlowBreakdownRow> bankRows;
  final List<ContabilidadFlowBreakdownRow> cashRows;
  final String Function(num) money;

  const _FlowOutflowsPanel({
    required this.bankRows,
    required this.cashRows,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <({String source, String label, double total})>[
      ...bankRows
          .take(4)
          .map((row) => (source: 'Bancos', label: row.label, total: row.total)),
      ...cashRows
          .take(4)
          .map(
            (row) => (source: 'Efectivo', label: row.label, total: row.total),
          ),
    ]..sort((a, b) => b.total.compareTo(a.total));
    final visible = rows.take(6).toList(growable: false);
    final maxTotal = visible.fold<double>(
      1,
      (max, row) => row.total > max ? row.total : max,
    );
    return ContabilidadGlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      blurSigma: 24,
      fillColor: kContabilidadSurface.withValues(alpha: 0.88),
      borderColor: Colors.white.withValues(alpha: 0.18),
      shadowColor: Colors.black.withValues(alpha: 0.10),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.54),
      bevelShadowColor: Colors.black.withValues(alpha: 0.16),
      glowColor: kContabilidadMint.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'En qué se fue el dinero',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Principales egresos visibles del periodo entre bancos y efectivo.',
            style: TextStyle(
              color: kContabilidadMutedInk,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            const Text(
              'Sin salidas visibles en esta ventana.',
              style: TextStyle(color: kContabilidadMutedInk),
            )
          else
            for (final row in visible) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
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
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          money(row.total),
                          style: const TextStyle(
                            color: kContabilidadMint,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      row.source,
                      style: const TextStyle(
                        color: kContabilidadMutedInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: (row.total / maxTotal).clamp(0.04, 1.0),
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: kContabilidadMint.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (row != visible.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _FlowTimelinePanel extends StatelessWidget {
  final List<ContabilidadFlowTimelinePoint> points;
  final String Function(num) money;
  final String Function(DateTime) shortDate;
  final Color Function(double) netColor;

  const _FlowTimelinePanel({
    required this.points,
    required this.money,
    required this.shortDate,
    required this.netColor,
  });

  @override
  Widget build(BuildContext context) {
    final visible = points.length <= 12
        ? points
        : points.sublist(points.length - 12, points.length);
    final maxNet = visible.fold<double>(
      1,
      (max, point) => point.netFlow.abs() > max ? point.netFlow.abs() : max,
    );
    return ContabilidadGlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      blurSigma: 24,
      fillColor: kContabilidadSurface.withValues(alpha: 0.88),
      borderColor: Colors.white.withValues(alpha: 0.18),
      shadowColor: Colors.black.withValues(alpha: 0.10),
      edgeHighlightColor: Colors.white.withValues(alpha: 0.54),
      bevelShadowColor: Colors.black.withValues(alpha: 0.16),
      glowColor: kContabilidadGlow.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pulso diario',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Vista corta para detectar qué días entró más dinero del que salió y cuáles presionaron la caja.',
            style: TextStyle(
              color: kContabilidadMutedInk,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            const Text(
              'No hay movimientos en la ventana seleccionada.',
              style: TextStyle(color: kContabilidadMutedInk),
            )
          else
            for (final point in visible) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 74,
                          child: Text(
                            shortDate(point.date),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          point.netFlow >= 0 ? '🟢' : '🔴',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            money(point.netFlow),
                            style: TextStyle(
                              color: netColor(point.netFlow),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: (point.netFlow.abs() / maxNet).clamp(
                        0.04,
                        1.0,
                      ),
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: netColor(
                            point.netFlow,
                          ).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Entró ${money(point.realInflows)} · salió ${money(point.realOutflows)} · traspasos internos ${money(point.internalTransfers)}',
                      style: const TextStyle(
                        color: kContabilidadMutedInk,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (point != visible.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}
