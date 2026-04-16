import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../shared/app_shell.dart';
import '../shared/app_ui/app_ui_widgets.dart';
import '../shared/archetypes/auxiliary_surfaces/date_picker_surface.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/contract_popup_surface.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/contract_grid_scaled_row.dart';
import '../shared/ui_contract_core/theme/contract_tokens.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/ui_contract_core/theme/anchored_action_slot.dart';
import '../shared/utils/number_formatters.dart';
import 'menudeo_catalog_page.dart';
import 'menudeo_dashboard_page.dart';
import 'menudeo_demo_mode.dart';
import 'menudeo_deposits_expenses_page.dart';
import 'menudeo_filter_widgets.dart';
import 'menudeo_header_brand.dart';
import 'menudeo_metric_card.dart';
import 'menudeo_price_adjustments_page.dart';
import 'menudeo_session_confirm_dialog.dart';
import 'menudeo_sales_page.dart';
import 'menudeo_tickets_page.dart';
import 'menudeo_theme.dart';

class MenudeoCashCutsPage extends StatefulWidget {
  final bool instantOpen;

  const MenudeoCashCutsPage({super.key, this.instantOpen = false});

  @override
  State<MenudeoCashCutsPage> createState() => _MenudeoCashCutsPageState();
}

class _CashCutRow {
  final String? id;
  final DateTime date;
  final double openingCash;
  final double salesTotal;
  final double purchasesTotal;
  final double depositsTotal;
  final double expensesTotal;
  final double theoreticalCashTotal;
  final double countedCashTotal;
  final double differenceTotal;
  final int pendingChecksCount;
  final String status;
  final String notes;
  final bool isLocalFallback;

  const _CashCutRow({
    required this.id,
    required this.date,
    required this.openingCash,
    required this.salesTotal,
    required this.purchasesTotal,
    required this.depositsTotal,
    required this.expensesTotal,
    required this.theoreticalCashTotal,
    required this.countedCashTotal,
    required this.differenceTotal,
    required this.pendingChecksCount,
    required this.status,
    required this.notes,
    this.isLocalFallback = false,
  });

  factory _CashCutRow.fromMap(Map<String, dynamic> row) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      return DateTime.tryParse((value ?? '').toString()) ?? DateTime.now();
    }

    double parseNum(dynamic value) =>
        double.tryParse((value ?? '').toString()) ?? 0;

    return _CashCutRow(
      id: row['id']?.toString(),
      date: parseDate(row['cut_date']),
      openingCash: parseNum(row['opening_cash']),
      salesTotal: parseNum(row['sales_total']),
      purchasesTotal: parseNum(row['purchases_total']),
      depositsTotal: parseNum(row['deposits_total']),
      expensesTotal: parseNum(row['expenses_total']),
      theoreticalCashTotal: parseNum(row['theoretical_cash_total']),
      countedCashTotal: parseNum(row['counted_cash_total']),
      differenceTotal: parseNum(row['difference_total']),
      pendingChecksCount:
          int.tryParse((row['pending_checks_count'] ?? '').toString()) ?? 0,
      status: (row['status'] ?? 'ABIERTO').toString(),
      notes: (row['notes'] ?? '').toString(),
    );
  }

  _CashCutRow copyWithLocalFallback() {
    return _CashCutRow(
      id: id,
      date: date,
      openingCash: openingCash,
      salesTotal: salesTotal,
      purchasesTotal: purchasesTotal,
      depositsTotal: depositsTotal,
      expensesTotal: expensesTotal,
      theoreticalCashTotal: theoreticalCashTotal,
      countedCashTotal: countedCashTotal,
      differenceTotal: differenceTotal,
      pendingChecksCount: pendingChecksCount,
      status: status,
      notes: notes,
      isLocalFallback: true,
    );
  }
}

class _MenudeoCashCutsPageState extends State<MenudeoCashCutsPage> {
  final SupabaseClient _supa = Supabase.instance.client;
  bool _menuOpen = false;
  bool _loading = true;
  bool _usingFallback = false;
  bool _canReturnToDirection = false;
  int _currentPage = 0;
  int _pageSize = 40;
  List<_CashCutRow> _rows = const <_CashCutRow>[];

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadCuts());
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
    });
  }

  Future<void> _loadCuts() async {
    setState(() => _loading = true);
    if (kMenudeoForceDemoMode) {
      if (!mounted) return;
      setState(() {
        _rows = _fallbackCuts();
        _usingFallback = true;
        _loading = false;
      });
      return;
    }
    try {
      final data = await _supa
          .from('vw_men_cash_cuts_grid')
          .select('*')
          .order('cut_date', ascending: false);
      if (!mounted) return;
      final rows = (data as List)
          .cast<Map<String, dynamic>>()
          .map(_CashCutRow.fromMap)
          .toList(growable: false);
      setState(() {
        _rows = rows.isEmpty ? _fallbackCuts() : rows;
        _usingFallback = rows.isEmpty;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _rows = _fallbackCuts();
        _usingFallback = true;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cargar el historial real de cortes: $error',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<_CashCutRow> _fallbackCuts() {
    return <_CashCutRow>[
      _CashCutRow(
        id: null,
        date: DateTime.now(),
        openingCash: 12500,
        salesTotal: 18940,
        purchasesTotal: 14320,
        depositsTotal: 3500,
        expensesTotal: 2180,
        theoreticalCashTotal: 18440,
        countedCashTotal: 18440,
        differenceTotal: 0,
        pendingChecksCount: 2,
        status: 'CON_PENDIENTES',
        notes: 'Faltan 2 gastos por ticket físico.',
        isLocalFallback: true,
      ),
      _CashCutRow(
        id: null,
        date: DateTime.now().subtract(const Duration(days: 1)),
        openingCash: 9800,
        salesTotal: 16200,
        purchasesTotal: 12050,
        depositsTotal: 2100,
        expensesTotal: 1600,
        theoreticalCashTotal: 14450,
        countedCashTotal: 14350,
        differenceTotal: -100,
        pendingChecksCount: 1,
        status: 'CERRADO',
        notes: 'Diferencia menor ajustada con observación.',
        isLocalFallback: true,
      ),
    ];
  }

  int _effectiveCurrentPageFor(int totalRows) {
    if (totalRows <= 0) return 0;
    final maxPage = (totalRows - 1) ~/ _pageSize;
    return _currentPage.clamp(0, maxPage);
  }

  int _totalPagesFor(int totalRows) {
    if (totalRows <= 0) return 1;
    return ((totalRows - 1) ~/ _pageSize) + 1;
  }

  List<_CashCutRow> _pageRows(List<_CashCutRow> rows) {
    if (rows.isEmpty) return const <_CashCutRow>[];
    final currentPage = _effectiveCurrentPageFor(rows.length);
    final start = currentPage * _pageSize;
    final end = math.min(start + _pageSize, rows.length);
    return rows.sublist(start, end);
  }

  String _money(num value) => formatMoney(value);

  String _fmtDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  Future<void> _goBack() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const MenudeoDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openCatalogPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoCatalogPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openPriceAdjustmentsPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoPriceAdjustmentsPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openTicketsPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoTicketsPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openSalesPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoSalesPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openDepositsExpensesPage() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MenudeoDepositsExpensesPage(instantOpen: true),
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Menudeo':
        unawaited(_goBack());
        return;
      case 'Catálogo':
        unawaited(_openCatalogPage());
        return;
      case 'Ajuste de precios':
        unawaited(_openPriceAdjustmentsPage());
        return;
      case 'Tickets de menudeo':
        unawaited(_openTicketsPage());
        return;
      case 'Ventas menudeo':
        unawaited(_openSalesPage());
        return;
      case 'Depósitos y gastos':
        unawaited(_openDepositsExpensesPage());
        return;
      case 'Corte de caja':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
    }
  }

  Future<void> _logout() async {
    final ok = await showMenudeoSessionConfirmDialog(context);
    if (ok != true || !mounted) return;
    await signOutAndRouteToLogin(context);
  }

  Future<void> _openEditor({_CashCutRow? initial}) async {
    final result = await showDialog<_CashCutRow>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.24),
      builder: (context) => _CashCutEditorDialog(initial: initial),
    );
    if (result == null || !mounted) return;

    final payload = <String, dynamic>{
      'cut_date': result.date.toIso8601String().split('T').first,
      'opening_cash': result.openingCash,
      'sales_total': result.salesTotal,
      'purchases_total': result.purchasesTotal,
      'deposits_total': result.depositsTotal,
      'expenses_total': result.expensesTotal,
      'theoretical_cash_total': result.theoreticalCashTotal,
      'counted_cash_total': result.countedCashTotal,
      'difference_total': result.differenceTotal,
      'pending_checks_count': result.pendingChecksCount,
      'status': result.status,
      'notes': result.notes,
    };

    if (kMenudeoForceDemoMode) {
      setState(() {
        final nextRows = <_CashCutRow>[
          result.copyWithLocalFallback(),
          ..._rows.where((r) => _fmtDate(r.date) != _fmtDate(result.date)),
        ];
        nextRows.sort((a, b) => b.date.compareTo(a.date));
        _rows = nextRows;
        _usingFallback = true;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Corte actualizado solo en demo'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await _supa.from('men_cash_cuts').upsert(payload, onConflict: 'cut_date');
      await _loadCuts();
    } catch (error) {
      setState(() {
        final nextRows = <_CashCutRow>[
          result,
          ..._rows.where((r) => _fmtDate(r.date) != _fmtDate(result.date)),
        ];
        nextRows.sort((a, b) => b.date.compareTo(a.date));
        _rows = nextRows;
        _usingFallback = true;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar en base todavía: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleRows = _pageRows(_rows);
    final totalPages = _totalPagesFor(_rows.length);
    final currentPage = _effectiveCurrentPageFor(_rows.length);
    return AreaThemeScope(
      tokens: menudeoAreaTokens,
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
          background: const _CashCutsBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 6,
          padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
          leadingBuilder: (_, anim) => _CashCutsHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, contentAnim) => MenudeoHeaderBrand(
            contentAnim: contentAnim,
            title: 'Cortes de Caja',
          ),
          trailingBuilder: (_, anim) => _CashCutsHeaderButton(
            label: 'Cerrar sesión',
            icon: Icons.logout_rounded,
            onTap: _logout,
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 56,
                      right: 2,
                      bottom: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CashCutsModuleTopBar(
                          rows: _rows,
                          usingFallback: _usingFallback,
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ContractGlassCard(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                            child: _loading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _CashCutsGrid(
                                    rows: visibleRows,
                                    money: _money,
                                    fmtDate: _fmtDate,
                                    onOpen: (row) => _openEditor(initial: row),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: MenudeoGridPager(
                            currentPage: currentPage,
                            totalPages: totalPages,
                            pageSize: _pageSize,
                            totalRows: _rows.length,
                            onPrevious: currentPage > 0
                                ? () => setState(
                                    () => _currentPage = currentPage - 1,
                                  )
                                : null,
                            onNext: currentPage < totalPages - 1
                                ? () => setState(
                                    () => _currentPage = currentPage + 1,
                                  )
                                : null,
                            onPageSizeChanged: (value) {
                              setState(() {
                                _pageSize = value;
                                _currentPage = 0;
                              });
                            },
                          ),
                        ),
                      ],
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
                  child: _CashCutsSidePanel(
                    onNavigate: _handleNavigationAction,
                    onBack: _goBack,
                    canReturnToDirection: _canReturnToDirection,
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

class _CashCutsGrid extends StatelessWidget {
  final List<_CashCutRow> rows;
  final String Function(num value) money;
  final String Function(DateTime value) fmtDate;
  final ValueChanged<_CashCutRow> onOpen;

  const _CashCutsGrid({
    required this.rows,
    required this.money,
    required this.fmtDate,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    const headerStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w800);
    const totalWidth =
        110 + 120 + 120 + 120 + 120 + 120 + 120 + 120 + 110 + 150 + 48;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          color: Colors.black.withValues(alpha: 0.03),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  child: ContractGridScaledRow(
                    child: SizedBox(
                      width: totalWidth.toDouble(),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 110,
                            child: MenudeoGridHeaderFilterCell(
                              label: 'Fecha',
                              style: headerStyle,
                              active: false,
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text('Apertura', style: headerStyle),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text('Ventas', style: headerStyle),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text('Compras', style: headerStyle),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text('Depósitos', style: headerStyle),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text('Gastos', style: headerStyle),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text('Caja final', style: headerStyle),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text('Conteo', style: headerStyle),
                          ),
                          SizedBox(
                            width: 110,
                            child: Text('Pend.', style: headerStyle),
                          ),
                          SizedBox(
                            width: 150,
                            child: Text('Estado', style: headerStyle),
                          ),
                          SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'Sin cortes en el historial actual.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: tokens.badgeText,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final row = rows[index];
                return _CashCutGridRow(
                  row: row,
                  money: money,
                  fmtDate: fmtDate,
                  onOpen: () => onOpen(row),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CashCutsModuleTopBar extends StatelessWidget {
  final List<_CashCutRow> rows;
  final bool usingFallback;

  const _CashCutsModuleTopBar({
    required this.rows,
    required this.usingFallback,
  });

  String _money(num value) => formatMoney(value);

  @override
  Widget build(BuildContext context) {
    final totalDifference = rows.fold<double>(
      0,
      (sum, row) => sum + row.differenceTotal,
    );
    final pendingCount = rows.fold<int>(
      0,
      (sum, row) => sum + row.pendingChecksCount,
    );
    final closedCount = rows
        .where((row) => row.status.toUpperCase() == 'CERRADO')
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Cortes de caja',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        AppGlassToolbarPanel(
          child: Text(
            usingFallback
                ? 'Mostrando base local de referencia mientras se conecta el historial real.'
                : 'Histórico automático de aperturas y cortes cerrados desde el dashboard.',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              MenudeoMetricCard(
                icon: Icons.event_note_rounded,
                title: 'CORTES',
                value: '${rows.length}',
                detail: '$closedCount cerrados',
                accent: menudeoAreaTokens.primaryStrong,
              ),
              MenudeoMetricCard(
                icon: Icons.pending_actions_rounded,
                title: 'PENDIENTES',
                value: '$pendingCount',
                detail: pendingCount == 1
                    ? '1 por revisar'
                    : '$pendingCount por revisar',
                accent: menudeoAreaTokens.accent,
              ),
              MenudeoMetricCard(
                icon: Icons.balance_rounded,
                title: 'DIFERENCIA ACUM.',
                value: _money(totalDifference),
                detail: usingFallback
                    ? 'Base demo activa'
                    : 'Histórico visible',
                accent: const Color(0xFFB27253),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CashCutGridRow extends StatefulWidget {
  final _CashCutRow row;
  final String Function(num value) money;
  final String Function(DateTime value) fmtDate;
  final VoidCallback onOpen;

  const _CashCutGridRow({
    required this.row,
    required this.money,
    required this.fmtDate,
    required this.onOpen,
  });

  @override
  State<_CashCutGridRow> createState() => _CashCutGridRowState();
}

class _CashCutGridRowState extends State<_CashCutGridRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    const rowContentWidth =
        110 + 120 + 120 + 120 + 120 + 120 + 120 + 120 + 110 + 150 + 48;

    Widget divider() => Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: tokens.border.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(999),
      ),
    );

    Widget cell({
      required double width,
      required Widget child,
      bool includeDivider = true,
    }) {
      return SizedBox(
        width: width,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(child: child),
            if (includeDivider) divider(),
          ],
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        scale: _hovering ? 1.003 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _hovering
                  ? [
                      Colors.white.withValues(alpha: 0.90),
                      const Color(0xFFF4E6DD).withValues(alpha: 0.82),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.74),
                      const Color(0xFFF7ECE5).withValues(alpha: 0.68),
                    ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _hovering
                  ? tokens.primarySoft.withValues(alpha: 0.30)
                  : tokens.border.withValues(alpha: 0.64),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.42),
                blurRadius: 18,
                offset: const Offset(-2, -2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovering ? 0.10 : 0.06),
                blurRadius: _hovering ? 20 : 14,
                offset: Offset(0, _hovering ? 12 : 8),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: constraints.maxWidth,
                child: ContractGridScaledRow(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: widget.onOpen,
                      onDoubleTap: widget.onOpen,
                      child: SizedBox(
                        width: rowContentWidth.toDouble(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            cell(
                              width: 110,
                              child: TextButton(
                                onPressed: widget.onOpen,
                                style: TextButton.styleFrom(
                                  foregroundColor: tokens.primaryStrong,
                                  padding: EdgeInsets.zero,
                                  alignment: Alignment.centerLeft,
                                  minimumSize: Size.zero,
                                ),
                                child: Text(
                                  widget.fmtDate(widget.row.date),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: tokens.primaryStrong,
                                  ),
                                ),
                              ),
                            ),
                            cell(
                              width: 120,
                              child: Text(widget.money(widget.row.openingCash)),
                            ),
                            cell(
                              width: 120,
                              child: Text(widget.money(widget.row.salesTotal)),
                            ),
                            cell(
                              width: 120,
                              child: Text(
                                widget.money(widget.row.purchasesTotal),
                              ),
                            ),
                            cell(
                              width: 120,
                              child: Text(
                                widget.money(widget.row.depositsTotal),
                              ),
                            ),
                            cell(
                              width: 120,
                              child: Text(
                                widget.money(widget.row.expensesTotal),
                              ),
                            ),
                            cell(
                              width: 120,
                              child: Text(
                                widget.money(widget.row.theoreticalCashTotal),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: tokens.primaryStrong,
                                ),
                              ),
                            ),
                            cell(
                              width: 120,
                              child: Text(
                                widget.money(widget.row.countedCashTotal),
                              ),
                            ),
                            cell(
                              width: 110,
                              child: Text('${widget.row.pendingChecksCount}'),
                            ),
                            cell(
                              width: 150,
                              child: _CutStatusChip(
                                status: widget.row.status,
                                fallback: widget.row.isLocalFallback,
                              ),
                              includeDivider: false,
                            ),
                            AnchoredActionSlot(
                              width: 48,
                              trailingWidth: 36,
                              gap: 0,
                              leading: const SizedBox.shrink(),
                              trailing: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: tokens.primarySoft.withValues(
                                      alpha: 0.24,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  color: tokens.primaryStrong,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CashCutEditorDialog extends StatefulWidget {
  final _CashCutRow? initial;

  const _CashCutEditorDialog({required this.initial});

  @override
  State<_CashCutEditorDialog> createState() => _CashCutEditorDialogState();
}

class _CashCutEditorDialogState extends State<_CashCutEditorDialog> {
  late final TextEditingController _dateC;
  late final TextEditingController _openingC;
  late final TextEditingController _salesC;
  late final TextEditingController _purchasesC;
  late final TextEditingController _depositsC;
  late final TextEditingController _expensesC;
  late final TextEditingController _countedC;
  late final TextEditingController _pendingC;
  late final TextEditingController _notesC;
  String _status = 'ABIERTO';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final now = initial?.date ?? DateTime.now();
    _dateC = TextEditingController(text: _fmtDate(now));
    _openingC = TextEditingController(text: _num(initial?.openingCash));
    _salesC = TextEditingController(text: _num(initial?.salesTotal));
    _purchasesC = TextEditingController(text: _num(initial?.purchasesTotal));
    _depositsC = TextEditingController(text: _num(initial?.depositsTotal));
    _expensesC = TextEditingController(text: _num(initial?.expensesTotal));
    _countedC = TextEditingController(text: _num(initial?.countedCashTotal));
    _pendingC = TextEditingController(
      text: (initial?.pendingChecksCount ?? 0).toString(),
    );
    _notesC = TextEditingController(text: initial?.notes ?? '');
    _status = initial?.status ?? 'ABIERTO';
  }

  @override
  void dispose() {
    _dateC.dispose();
    _openingC.dispose();
    _salesC.dispose();
    _purchasesC.dispose();
    _depositsC.dispose();
    _expensesC.dispose();
    _countedC.dispose();
    _pendingC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  String _num(double? value) =>
      value == null || value == 0 ? '' : value.toStringAsFixed(2);

  String _fmtDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  DateTime _parseUiDate(String raw) {
    final parts = raw.trim().split('/');
    if (parts.length != 3) return DateTime.now();
    final day = int.tryParse(parts[0]) ?? DateTime.now().day;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;
    final year = int.tryParse(parts[2]) ?? DateTime.now().year;
    return DateTime(year, month, day);
  }

  double _parseMoney(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  double get _theoreticalCash =>
      _parseMoney(_openingC) +
      _parseMoney(_salesC) +
      _parseMoney(_depositsC) -
      _parseMoney(_purchasesC) -
      _parseMoney(_expensesC);

  double get _difference => _parseMoney(_countedC) - _theoreticalCash;

  Future<void> _pickCutDate(
    void Function(void Function()) setLocalState,
  ) async {
    final initialDate = _parseUiDate(_dateC.text);
    final picked = await showContractDatePickerSurface(
      context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      title: 'Selecciona fecha del corte',
    );
    if (picked == null) return;
    setLocalState(() => _dateC.text = _fmtDate(picked));
  }

  void _save() {
    Navigator.of(context).pop(
      _CashCutRow(
        id: widget.initial?.id,
        date: _parseUiDate(_dateC.text),
        openingCash: _parseMoney(_openingC),
        salesTotal: _parseMoney(_salesC),
        purchasesTotal: _parseMoney(_purchasesC),
        depositsTotal: _parseMoney(_depositsC),
        expensesTotal: _parseMoney(_expensesC),
        theoreticalCashTotal: _theoreticalCash,
        countedCashTotal: _parseMoney(_countedC),
        differenceTotal: _difference,
        pendingChecksCount: int.tryParse(_pendingC.text.trim()) ?? 0,
        status: _status,
        notes: _notesC.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = menudeoAreaTokens;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: AreaThemeScope(
        tokens: menudeoAreaTokens,
        child: Theme(
          data: _menudeoCashCutsDialogTheme(
            Theme.of(context),
            menudeoAreaTokens,
          ),
          child: ContractPopupSurface(
            constraints: const BoxConstraints(
              minWidth: 760,
              maxWidth: 980,
              maxHeight: 820,
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: StatefulBuilder(
              builder: (context, setLocalState) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CutDialogHeader(
                      onClose: () => Navigator.of(context).pop(),
                      positionLabel: widget.initial == null
                          ? 'Nuevo'
                          : _fmtDate(widget.initial!.date),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CutTopChip(label: 'Fecha', value: _dateC.text),
                        _CutTopChip(label: 'Estado', value: _status),
                        _CutTopChip(
                          label: 'Pendientes',
                          value: _pendingC.text.trim().isEmpty
                              ? '0'
                              : _pendingC.text.trim(),
                        ),
                        _CutTopChip(
                          label: 'Diferencia',
                          value: formatMoney(_difference),
                          emphasized: _difference == 0,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ContractGlassCard(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                16,
                                18,
                                16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _CutField(
                                          label: 'Fecha',
                                          compact: true,
                                          child: InkWell(
                                            onTap: () =>
                                                _pickCutDate(setLocalState),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    _dateC.text,
                                                    style: _cutInputTextStyle(
                                                      tokens,
                                                    ),
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.calendar_month_rounded,
                                                  size: 18,
                                                  color: tokens.primaryStrong,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _CutField(
                                          label: 'Estado',
                                          compact: true,
                                          child: SegmentedButton<String>(
                                            style: _cutSegmentedButtonStyle(
                                              tokens,
                                            ),
                                            segments: const [
                                              ButtonSegment(
                                                value: 'ABIERTO',
                                                label: Text('Abierto'),
                                              ),
                                              ButtonSegment(
                                                value: 'CERRADO',
                                                label: Text('Cerrado'),
                                              ),
                                              ButtonSegment(
                                                value: 'CON_PENDIENTES',
                                                label: Text('Pendientes'),
                                              ),
                                            ],
                                            selected: <String>{_status},
                                            onSelectionChanged: (value) {
                                              setLocalState(
                                                () => _status = value.first,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _CutField(
                                          label: 'Apertura de caja',
                                          compact: true,
                                          child: _moneyField(
                                            _openingC,
                                            setLocalState,
                                            tokens,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _CutField(
                                          label: 'Ventas de hoy',
                                          compact: true,
                                          child: _moneyField(
                                            _salesC,
                                            setLocalState,
                                            tokens,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _CutField(
                                          label: 'Compras de hoy',
                                          compact: true,
                                          child: _moneyField(
                                            _purchasesC,
                                            setLocalState,
                                            tokens,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _CutField(
                                          label: 'Depósitos de hoy',
                                          compact: true,
                                          child: _moneyField(
                                            _depositsC,
                                            setLocalState,
                                            tokens,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _CutField(
                                          label: 'Gastos de hoy',
                                          compact: true,
                                          child: _moneyField(
                                            _expensesC,
                                            setLocalState,
                                            tokens,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _CutField(
                                          label: 'Conteo real',
                                          compact: true,
                                          child: _moneyField(
                                            _countedC,
                                            setLocalState,
                                            tokens,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _CutField(
                                          label: 'Caja teórica',
                                          compact: true,
                                          child: Text(
                                            formatMoney(_theoreticalCash),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: tokens.primaryStrong,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _CutField(
                                          label: 'Diferencia',
                                          compact: true,
                                          child: Text(
                                            formatMoney(_difference),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: _difference == 0
                                                  ? const Color(0xFF41724A)
                                                  : const Color(0xFF9F4A34),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _CutField(
                                          label: 'Pendientes por comprobar',
                                          compact: true,
                                          child: TextField(
                                            controller: _pendingC,
                                            keyboardType: TextInputType.number,
                                            style: _cutInputTextStyle(tokens),
                                            decoration:
                                                InputDecoration.collapsed(
                                                  hintText: '0',
                                                  hintStyle: _cutHintTextStyle(
                                                    tokens,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _CutField(
                                    label: 'Observaciones',
                                    compact: true,
                                    child: TextField(
                                      controller: _notesC,
                                      maxLines: 3,
                                      style: _cutInputTextStyle(tokens),
                                      decoration: InputDecoration.collapsed(
                                        hintText:
                                            'Notas del corte, diferencias o pendientes arrastrados',
                                        hintStyle: _cutHintTextStyle(tokens),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            ContractGlassCard(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                16,
                                18,
                                16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Resumen del corte',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: tokens.primaryStrong,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _CutField(
                                          label: 'Caja teórica',
                                          child: Text(
                                            formatMoney(_theoreticalCash),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: tokens.primaryStrong,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _CutField(
                                          label: 'Diferencia',
                                          child: Text(
                                            formatMoney(_difference),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: _difference == 0
                                                  ? const Color(0xFF41724A)
                                                  : const Color(0xFF9F4A34),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _CutField(
                                          label: 'Pendientes por comprobar',
                                          child: TextField(
                                            controller: _pendingC,
                                            keyboardType: TextInputType.number,
                                            style: _cutInputTextStyle(tokens),
                                            decoration:
                                                InputDecoration.collapsed(
                                                  hintText: '0',
                                                  hintStyle: _cutHintTextStyle(
                                                    tokens,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _CutField(
                                    label: 'Observaciones',
                                    child: TextField(
                                      controller: _notesC,
                                      maxLines: 3,
                                      style: _cutInputTextStyle(tokens),
                                      decoration: InputDecoration.collapsed(
                                        hintText:
                                            'Notas del corte, diferencias o pendientes arrastrados',
                                        hintStyle: _cutHintTextStyle(tokens),
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
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: _cutSecondaryButtonStyle(tokens),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          style: _cutPrimaryButtonStyle(tokens),
                          onPressed: _save,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Guardar corte'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _moneyField(
    TextEditingController controller,
    void Function(void Function()) setLocalState,
    ContractAreaTokens tokens,
  ) {
    return TextField(
      controller: controller,
      onChanged: (_) => setLocalState(() {}),
      style: _cutInputTextStyle(tokens),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration.collapsed(
        hintText: '0.00',
        hintStyle: _cutHintTextStyle(tokens),
      ),
    );
  }
}

class _CutField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool compact;

  const _CutField({
    required this.label,
    required this.child,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 8, 12, 8)
          : const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.88),
            const Color(0xFFF5ECE6).withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.primarySoft.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.32),
            blurRadius: 8,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11.5 : 12,
              fontWeight: FontWeight.w900,
              color: tokens.badgeText,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          child,
        ],
      ),
    );
  }
}

TextStyle _cutInputTextStyle(ContractAreaTokens tokens) => TextStyle(
  fontSize: 14.5,
  fontWeight: FontWeight.w700,
  color: tokens.primaryStrong,
);

TextStyle _cutHintTextStyle(ContractAreaTokens tokens) => TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: tokens.badgeText.withValues(alpha: 0.84),
);

ButtonStyle _cutPrimaryButtonStyle(ContractAreaTokens tokens) {
  return FilledButton.styleFrom(
    backgroundColor: tokens.primaryStrong,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

ButtonStyle _cutSecondaryButtonStyle(ContractAreaTokens tokens) {
  return OutlinedButton.styleFrom(
    foregroundColor: tokens.primaryStrong,
    backgroundColor: Colors.white.withValues(alpha: 0.55),
    side: BorderSide(color: tokens.primarySoft.withValues(alpha: 0.9)),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );
}

ButtonStyle _cutSegmentedButtonStyle(ContractAreaTokens tokens) {
  return SegmentedButton.styleFrom(
    visualDensity: VisualDensity.compact,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    foregroundColor: tokens.primaryStrong,
    selectedForegroundColor: tokens.primaryStrong,
    selectedBackgroundColor: tokens.badgeBackground.withValues(alpha: 0.92),
    backgroundColor: Colors.white.withValues(alpha: 0.72),
    side: BorderSide(color: tokens.primarySoft.withValues(alpha: 0.42)),
    textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
  );
}

ThemeData _menudeoCashCutsDialogTheme(
  ThemeData base,
  ContractAreaTokens tokens,
) {
  final scheme = base.colorScheme.copyWith(
    primary: tokens.primaryStrong,
    onPrimary: Colors.white,
    secondary: tokens.primaryStrong,
    onSecondary: Colors.white,
    tertiary: tokens.accent,
    surfaceTint: tokens.surfaceTint,
  );
  return base.copyWith(
    colorScheme: scheme,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: tokens.primaryStrong,
      selectionColor: tokens.primarySoft.withValues(alpha: 0.42),
      selectionHandleColor: tokens.primaryStrong,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: _cutPrimaryButtonStyle(tokens),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _cutSecondaryButtonStyle(tokens),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: tokens.primaryStrong),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: _cutSegmentedButtonStyle(tokens),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: _cutHintTextStyle(tokens),
    ),
  );
}

class _CutDialogHeader extends StatelessWidget {
  final VoidCallback onClose;
  final String? positionLabel;

  const _CutDialogHeader({required this.onClose, this.positionLabel});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.54),
            const Color(0xFFF4E8E0).withValues(alpha: 0.30),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.38),
            blurRadius: 16,
            offset: const Offset(-2, -2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DicsaLogoD(size: 32),
              const SizedBox(width: 10),
              Text(
                'DICSA',
                style: TextStyle(
                  color: tokens.primaryStrong,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
          Positioned(
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (positionLabel != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      positionLabel!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: tokens.badgeText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                _CutDialogActionButton(
                  icon: Icons.close_rounded,
                  onTap: onClose,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CutDialogActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CutDialogActionButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.96),
                const Color(0xFFF2E4DB).withValues(alpha: 0.88),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: tokens.primarySoft.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.34),
                blurRadius: 8,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
          child: Icon(icon, color: tokens.primaryStrong, size: 20),
        ),
      ),
    );
  }
}

class _CutTopChip extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _CutTopChip({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 148),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: emphasized
              ? [
                  tokens.badgeBackground.withValues(alpha: 0.95),
                  const Color(0xFFF2DFD4).withValues(alpha: 0.88),
                ]
              : [
                  Colors.white.withValues(alpha: 0.90),
                  const Color(0xFFF6ECE5).withValues(alpha: 0.80),
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.primarySoft.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.34),
            blurRadius: 8,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: tokens.badgeText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasized ? 14.5 : 13.5,
              fontWeight: FontWeight.w900,
              color: tokens.primaryStrong,
            ),
          ),
        ],
      ),
    );
  }
}

class _CutStatusChip extends StatelessWidget {
  final String status;
  final bool fallback;

  const _CutStatusChip({required this.status, required this.fallback});

  @override
  Widget build(BuildContext context) {
    Color tone;
    switch (status) {
      case 'CERRADO':
        tone = const Color(0xFF4E8B58);
        break;
      case 'CON_PENDIENTES':
        tone = const Color(0xFFC47A18);
        break;
      default:
        tone = const Color(0xFF8A5B3E);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.24)),
      ),
      child: Text(
        fallback ? '$status · LOCAL' : status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: tone,
        ),
      ),
    );
  }
}

class _CashCutsHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;

  const _CashCutsHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
  });

  @override
  State<_CashCutsHeaderButton> createState() => _CashCutsHeaderButtonState();
}

class _CashCutsHeaderButtonState extends State<_CashCutsHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: _hovered ? 1.026 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            onTap: () {
              if (widget.onTap != null) {
                unawaited(widget.onTap!());
                return;
              }
              widget.onTapSync?.call();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _hovered ? -2.5 : 0, 0),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: _hovered ? 0.30 : 0.22),
                    tokens.surfaceTint.withValues(
                      alpha: _hovered ? 0.34 : 0.24,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _hovered
                      ? Colors.white.withValues(alpha: 0.70)
                      : Colors.white.withValues(alpha: 0.46),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: _hovered ? 28 : 16,
                    color: Colors.black.withValues(
                      alpha: _hovered ? 0.16 : 0.08,
                    ),
                    offset: Offset(0, _hovered ? 14 : 8),
                  ),
                  BoxShadow(
                    blurRadius: _hovered ? 20 : 10,
                    color: tokens.primaryStrong.withValues(
                      alpha: _hovered ? 0.10 : 0.04,
                    ),
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: tokens.primaryStrong),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: tokens.primaryStrong,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CashCutsSidePanel extends StatelessWidget {
  final Future<void> Function() onBack;
  final ValueChanged<String> onNavigate;
  final bool canReturnToDirection;

  const _CashCutsSidePanel({
    required this.onBack,
    required this.onNavigate,
    required this.canReturnToDirection,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ContractGlassCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Menudeo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              if (canReturnToDirection) ...[
                _CashCutsPanelItem(
                  icon: Icons.arrow_back_rounded,
                  title: 'Volver a Dirección',
                  onTap: onBack,
                ),
                const SizedBox(height: 10),
              ],
              const _CashCutsSectionHeader(label: 'MENU'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x66EFD7C2),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: tokens.primaryStrong.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  children: [
                    _CashCutsPanelItem(
                      icon: Icons.receipt_long_rounded,
                      title: 'Compras',
                      subtitle: 'Tickets virtuales de compra',
                      onTapSync: () => onNavigate('Tickets de menudeo'),
                    ),
                    const SizedBox(height: 8),
                    _CashCutsPanelItem(
                      icon: Icons.point_of_sale_rounded,
                      title: 'Ventas',
                      subtitle: 'Tickets virtuales de venta',
                      onTapSync: () => onNavigate('Ventas menudeo'),
                    ),
                    const SizedBox(height: 8),
                    _CashCutsPanelItem(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Depósitos y gastos',
                      subtitle: 'Vouchers de caja y egresos',
                      onTapSync: () => onNavigate('Depósitos y gastos'),
                    ),
                    const SizedBox(height: 8),
                    _CashCutsPanelItem(
                      icon: Icons.auto_graph_rounded,
                      title: 'Ajuste de precios',
                      subtitle: 'Cambios e historial',
                      onTapSync: () => onNavigate('Ajuste de precios'),
                    ),
                    const SizedBox(height: 8),
                    _CashCutsPanelItem(
                      icon: Icons.price_check_rounded,
                      title: 'Catálogo',
                      subtitle: 'Materiales, grupos y precios',
                      onTapSync: () => onNavigate('Catálogo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _CashCutsSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              _CashCutsPanelItem(
                icon: Icons.space_dashboard_rounded,
                title: 'Dashboard Menudeo',
                subtitle: 'Vista general del área',
                onTap: onBack,
              ),
              const SizedBox(height: 8),
              const _CashCutsPanelItem(
                icon: Icons.inventory_2_rounded,
                title: 'Corte de caja',
                subtitle: 'Historial y revisión',
                accented: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CashCutsSectionHeader extends StatelessWidget {
  final String label;

  const _CashCutsSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
            color: tokens.badgeText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: tokens.primarySoft.withValues(alpha: 0.32),
          ),
        ),
      ],
    );
  }
}

class _CashCutsPanelItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final bool accented;

  const _CashCutsPanelItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.onTapSync,
    this.accented = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          if (onTap != null) {
            await onTap!();
          } else {
            onTapSync?.call();
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              gradient: accented
                  ? const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFE5A56F), Color(0xFFCF7E59)],
                    )
                  : const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFF6E2D1), Color(0xFFE7B992)],
                    ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accented
                    ? const Color(0xFFF7DCC5)
                    : Colors.white.withValues(alpha: 0.58),
              ),
              boxShadow: accented
                  ? [
                      BoxShadow(
                        color: const Color(0xFFB46D4F).withValues(alpha: 0.22),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFFB97A5C).withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: accented
                              ? Colors.white
                              : const Color(0xFF7E4632),
                        ),
                      ),
                      if (hasSubtitle) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accented
                                ? Colors.white.withValues(alpha: 0.92)
                                : const Color(0xFF8F5A44),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CashCutsBackground extends StatelessWidget {
  const _CashCutsBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7EDE6), Color(0xFFD8C1B0), Color(0xFFA88973)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -120,
            right: -40,
            child: Container(
              width: 340,
              height: 340,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFD89A5C),
              ),
            ),
          ),
          Positioned(
            left: -120,
            bottom: -160,
            child: Container(
              width: 460,
              height: 460,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE4BCA7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
