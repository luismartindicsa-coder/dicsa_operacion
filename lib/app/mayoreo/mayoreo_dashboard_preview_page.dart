import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../auth/auth_access.dart';
import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/dialogs/contract_dialog_shell.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import '../shared/ui_contract_core/theme/glass_styles.dart';
import '../shared/utils/number_formatters.dart';
import 'mayoreo_accounts_page.dart';
import 'mayoreo_catalog_page.dart';
import 'mayoreo_data_store.dart';
import 'mayoreo_price_adjustments_page.dart';
import 'mayoreo_el_palomar_page.dart';
import 'mayoreo_sales_report_page.dart';
import 'mayoreo_theme.dart';

const String _kMayoreoSalesReportsTable = 'mayoreo_sales_reports';
const String _kMayoreoAccountsTable = 'mayoreo_accounts';
const String _kMayoreoPalomarMovementsTable = 'mayoreo_palomar_movements';
const String _kMayoreoPendingItemsTable = 'mayoreo_pending_items';

class MayoreoDashboardPreviewPage extends StatefulWidget {
  final bool instantOpen;

  const MayoreoDashboardPreviewPage({super.key, this.instantOpen = false});

  @override
  State<MayoreoDashboardPreviewPage> createState() =>
      _MayoreoDashboardPreviewPageState();
}

class _MayoreoDashboardPreviewPageState
    extends State<MayoreoDashboardPreviewPage> {
  final SupabaseClient _supa = Supabase.instance.client;
  Future<void> _persistPendingQueue = Future<void>.value();
  bool _menuOpen = false;
  bool _canReturnToDirection = false;
  List<_MayoreoPendingTask> _pendingTasks = const <_MayoreoPendingTask>[];
  _MayoreoDashboardSummary _summary = const _MayoreoDashboardSummary();

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
    unawaited(_loadDashboardState());
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
    });
  }

  Future<void> _loadDashboardState() async {
    final catalogSnapshot = await MayoreoDataStore.loadCatalogSnapshot();
    List<_MayoreoPendingTask> tasks = const <_MayoreoPendingTask>[];
    String? salesRaw;
    String? accountsRaw;
    String? palomarRaw;
    try {
      final responses = await Future.wait([
        _supa.from(_kMayoreoPendingItemsTable).select().order('due_date'),
        _supa.from(_kMayoreoSalesReportsTable).select(),
        _supa.from(_kMayoreoAccountsTable).select(),
        _supa.from(_kMayoreoPalomarMovementsTable).select(),
      ]);
      tasks = (responses[0] as List)
          .map(
            (item) => _MayoreoPendingTask.fromSupabase(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where((task) => !task.isSystemGenerated)
          .toList(growable: false);
      salesRaw = jsonEncode(<String, dynamic>{
        'rows': (responses[1] as List)
            .map(
              (row) => <String, dynamic>{
                'id': (row as Map)['id'],
                'approvedWeight': row['approved_weight'],
                'approvedPrice': row['approved_price'],
              },
            )
            .toList(growable: false),
      });
      accountsRaw = jsonEncode(<String, dynamic>{
        'rows': (responses[2] as List)
            .map(
              (row) => <String, dynamic>{
                'operationType': (row as Map)['operation_type'],
                'status': row['status'],
                'approvedAmount': row['approved_amount'],
                'paidAmount': row['paid_amount'],
                'estimatedPaymentDate': row['estimated_payment_date'],
                'clientName': row['client_name_snapshot'],
                'documentNumber': row['document_number'],
                'remision': row['remision'],
                'id': row['id'],
              },
            )
            .toList(growable: false),
      });
      palomarRaw = jsonEncode(<String, dynamic>{
        'movements': (responses[3] as List)
            .map(
              (row) => <String, dynamic>{
                'type': (row as Map)['type'],
                'amount': row['amount'],
                'sourceReportId': row['source_report_id'],
              },
            )
            .toList(growable: false),
      });
    } catch (_) {
      tasks = const <_MayoreoPendingTask>[];
    }
    final summary = _buildDashboardSummary(
      salesRaw: salesRaw,
      accountsRaw: accountsRaw,
      palomarRaw: palomarRaw,
      catalogSnapshot: catalogSnapshot,
    );
    if (!mounted) return;
    setState(() {
      _pendingTasks = tasks;
      _summary = summary;
    });
  }

  Future<void> _persistPendingTasks() async {
    final snapshot = _pendingTasks
        .map((task) => task.copyWith())
        .toList(growable: false);
    _persistPendingQueue = _persistPendingQueue
        .catchError((_) {})
        .then((_) => _persistPendingTasksToSupabase(snapshot));
    await _persistPendingQueue;
  }

  Future<void> _persistPendingTasksToSupabase(
    List<_MayoreoPendingTask> tasks,
  ) async {
    try {
      final manualTasks = tasks
          .where((task) => !task.isSystemGenerated)
          .toList(growable: false);
      if (manualTasks.isNotEmpty) {
        await _supa
            .from(_kMayoreoPendingItemsTable)
            .upsert(
              manualTasks
                  .map((task) => task.toSupabase())
                  .toList(growable: false),
              onConflict: 'id',
            );
      }
      final existing = await _supa
          .from(_kMayoreoPendingItemsTable)
          .select('id');
      final existingIds = (existing as List)
          .map((row) => (row as Map)['id'].toString())
          .toSet();
      final nextIds = manualTasks.map((task) => task.id).toSet();
      final deletedIds = existingIds
          .difference(nextIds)
          .toList(growable: false);
      if (deletedIds.isNotEmpty) {
        await _supa
            .from(_kMayoreoPendingItemsTable)
            .delete()
            .inFilter('id', deletedIds);
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar Pendientes: ${e.message}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _loadDashboardState();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar Pendientes. Se restauró el estado remoto.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _loadDashboardState();
    }
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
    );
  }

  Future<void> _openCatalog() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MayoreoCatalogPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openPriceAdjustments() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MayoreoPriceAdjustmentsPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openSalesReports() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MayoreoSalesReportPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openAccounts() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MayoreoAccountsPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openElPalomar() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      appPageRoute(
        page: const MayoreoElPalomarPage(instantOpen: true),
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  Future<void> _openMailHostinger() async {
    const url = 'https://mail.hostinger.com/';
    final opened = await launchUrlString(
      url,
      mode: LaunchMode.externalApplication,
    );
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo abrir mail.hostinger.com'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showStub(String label) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label quedará conectado en la siguiente fase de Mayoreo.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openPendingTasksDialog() async {
    final nextTasks = await showDialog<List<_MayoreoPendingTask>>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AreaThemeScope(
        tokens: mayoreoAreaTokens,
        child: _MayoreoPendingTasksDialog(
          initialTasks: _pendingTasks,
          automaticTasks: _summary.automaticPendingTasks,
          defaultSource: _canReturnToDirection ? 'DIRECCION' : 'VENTAS',
        ),
      ),
    );
    if (!mounted || nextTasks == null) return;
    setState(() => _pendingTasks = nextTasks);
    await _persistPendingTasks();
    await _loadDashboardState();
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case 'Dashboard Dirección':
        unawaited(_openDirectionDashboard());
        return;
      case 'Dashboard Mayoreo':
        if (_menuOpen) setState(() => _menuOpen = false);
        return;
      case 'Ventas Mayoreo':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openSalesReports());
        return;
      case 'Cuentas':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openAccounts());
        return;
      case 'Cuenta El Palomar':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openElPalomar());
        return;
      case 'Catálogo':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openCatalog());
        return;
      case 'Ajuste de precios':
        if (_menuOpen) setState(() => _menuOpen = false);
        unawaited(_openPriceAdjustments());
        return;
      default:
        if (_menuOpen) setState(() => _menuOpen = false);
        _showStub(label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final openPendingCount = _pendingTasks.where((task) => !task.isDone).length;
    final notificationCount =
        openPendingCount + _summary.automaticPendingTasks.length;
    return AreaThemeScope(
      tokens: mayoreoAreaTokens,
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
          background: const _MayoreoPreviewBackground(),
          wrapBodyInGlass: false,
          animateHeaderSlots: false,
          animateBody: !widget.instantOpen,
          headerBodySpacing: 8,
          padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
          leadingBuilder: (_, _) => _MayoreoHeaderButton(
            label: _menuOpen ? 'Cerrar panel' : 'Navegación',
            icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
            onTapSync: () => setState(() => _menuOpen = !_menuOpen),
          ),
          centerBuilder: (_, _) => const _MayoreoHeaderBrand(),
          trailingBuilder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MayoreoHeaderButton(
                label: 'Correo',
                icon: Icons.mail_outline_rounded,
                compact: true,
                onTap: _openMailHostinger,
              ),
              const SizedBox(width: 10),
              _MayoreoHeaderButton(
                label: 'Pendientes',
                icon: Icons.notifications_none_rounded,
                notificationCount: notificationCount,
                onTap: _openPendingTasksDialog,
              ),
              const SizedBox(width: 10),
              _MayoreoHeaderButton(
                label: 'Cerrar sesión',
                icon: Icons.logout_rounded,
                onTap: () async {},
              ),
            ],
          ),
          child: Stack(
            children: [
              _MayoreoPreviewBody(
                onOpenAccounts: _openAccounts,
                onOpenElPalomar: _openElPalomar,
                onOpenSalesReports: _openSalesReports,
                onOpenCatalog: _openCatalog,
                onOpenPriceAdjustments: _openPriceAdjustments,
                pendingTasks: _pendingTasks,
                onOpenPendingTasks: _openPendingTasksDialog,
                summary: _summary,
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
                  child: _MayoreoSidePanel(
                    canReturnToDirection: _canReturnToDirection,
                    onNavigate: _handleNavigationAction,
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

class _MayoreoPreviewBackground extends StatelessWidget {
  const _MayoreoPreviewBackground();

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.surfaceTint,
                const Color(0xFFFFF1B8),
                tokens.accent.withValues(alpha: 0.34),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: -260,
          top: -130,
          child: _backgroundCircle(
            760,
            LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.88),
                const Color(0xFFFFED9C),
              ],
            ),
          ),
        ),
        Positioned(
          right: -180,
          top: -70,
          child: _backgroundCircle(
            580,
            LinearGradient(
              colors: [
                const Color(0xFFFFE94A).withValues(alpha: 0.78),
                const Color(0xFFF9A411).withValues(alpha: 0.18),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          bottom: -260,
          child: _backgroundCircle(
            640,
            LinearGradient(
              colors: [
                const Color(0xFFF88C12).withValues(alpha: 0.22),
                tokens.primarySoft.withValues(alpha: 0.88),
              ],
            ),
          ),
        ),
        Positioned(
          right: -105,
          bottom: -120,
          child: IgnorePointer(
            child: Container(
              width: 320,
              height: 500,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(220),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFFE900).withValues(alpha: 0.90),
                    const Color(0xFFF5A10C).withValues(alpha: 0.86),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _backgroundCircle(double diameter, Gradient gradient) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              blurRadius: diameter * 0.10,
              spreadRadius: diameter * 0.015,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: SizedBox(width: diameter, height: diameter),
      ),
    );
  }
}

class _MayoreoHeaderBrand extends StatelessWidget {
  const _MayoreoHeaderBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.46)),
            boxShadow: [
              BoxShadow(
                color: mayoreoAreaTokens.glow.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Center(child: DicsaLogoD(size: 36, progress: 1)),
        ),
        const SizedBox(width: 14),
        const Text(
          'Dashboard Mayoreo',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: kMayoreoInk,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _MayoreoPreviewBody extends StatelessWidget {
  final Future<void> Function() onOpenAccounts;
  final Future<void> Function() onOpenElPalomar;
  final Future<void> Function() onOpenSalesReports;
  final Future<void> Function() onOpenCatalog;
  final Future<void> Function() onOpenPriceAdjustments;
  final List<_MayoreoPendingTask> pendingTasks;
  final Future<void> Function() onOpenPendingTasks;
  final _MayoreoDashboardSummary summary;

  const _MayoreoPreviewBody({
    required this.onOpenAccounts,
    required this.onOpenElPalomar,
    required this.onOpenSalesReports,
    required this.onOpenCatalog,
    required this.onOpenPriceAdjustments,
    required this.pendingTasks,
    required this.onOpenPendingTasks,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 56, right: 2, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MayoreoPalomarHeroCard(
                balance: summary.palomarBalance,
                detail: summary.palomarStatusLabel,
                movementCount: summary.palomarMovementCount,
                availableRemissions: summary.availablePalomarRemissions,
                onTap: onOpenElPalomar,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 1480
                      ? 5
                      : width >= 1160
                      ? 3
                      : width >= 820
                      ? 2
                      : 1;
                  const spacing = 16.0;
                  final cardWidth =
                      (width - ((columns - 1) * spacing)) / columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      _MayoreoMetricCard(
                        width: cardWidth,
                        icon: Icons.receipt_long_rounded,
                        title: 'Facturas pendientes',
                        value: '${summary.pendingInvoiceCount}',
                        detail:
                            '${_money(summary.pendingInvoiceAmount)} por cobrar',
                        accent: const Color(0xFFF39C12),
                        onTap: onOpenAccounts,
                      ),
                      _MayoreoMetricCard(
                        width: cardWidth,
                        icon: Icons.request_page_rounded,
                        title: 'Cheques pendientes',
                        value: '${summary.pendingCheckCount}',
                        detail:
                            '${_money(summary.pendingCheckAmount)} por conciliar',
                        accent: const Color(0xFFE3B208),
                        onTap: onOpenAccounts,
                      ),
                      _MayoreoMetricCard(
                        width: cardWidth,
                        icon: Icons.link_rounded,
                        title: 'Reportes pendientes',
                        value: '${summary.pendingReportsCount}',
                        detail: '${summary.relatedReportsCount} relacionados',
                        accent: const Color(0xFFC78A00),
                        onTap: onOpenSalesReports,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _MayoreoInsightGrid(
                tasks: pendingTasks,
                summary: summary,
                onOpenPendingTasks: onOpenPendingTasks,
                onOpenCatalog: onOpenCatalog,
                onOpenPriceAdjustments: onOpenPriceAdjustments,
                onOpenAccounts: onOpenAccounts,
                onOpenSalesReports: onOpenSalesReports,
                onOpenElPalomar: onOpenElPalomar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MayoreoPalomarHeroCard extends StatefulWidget {
  final double balance;
  final String detail;
  final int movementCount;
  final int availableRemissions;
  final Future<void> Function() onTap;

  const _MayoreoPalomarHeroCard({
    required this.balance,
    required this.detail,
    required this.movementCount,
    required this.availableRemissions,
    required this.onTap,
  });

  @override
  State<_MayoreoPalomarHeroCard> createState() =>
      _MayoreoPalomarHeroCardState();
}

class _MayoreoPalomarHeroCardState extends State<_MayoreoPalomarHeroCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            scale: _hovered ? 1.006 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()
                ..translateByDouble(0.0, _hovered ? -3.0 : 0.0, 0.0, 1.0),
              child: ContractGlassCard(
                padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(26),
                  onTap: () async => widget.onTap(),
                  child: Column(
                    children: [
                      Text(
                        'Saldo El Palomar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: tokens.primaryStrong.withValues(alpha: 0.84),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _money(widget.balance),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1F262B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.availableRemissions} remisiones disponibles · ${widget.movementCount} movimientos · ${widget.detail}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6A6966),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MayoreoMetricCard extends StatefulWidget {
  final double width;
  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final Color accent;
  final Future<void> Function()? onTap;

  const _MayoreoMetricCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.accent,
    this.onTap,
  });

  @override
  State<_MayoreoMetricCard> createState() => _MayoreoMetricCardState();
}

class _MayoreoMetricCardState extends State<_MayoreoMetricCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return SizedBox(
      width: widget.width,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: _hovered ? 1.008 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()
              ..translateByDouble(0.0, _hovered ? -3.0 : 0.0, 0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: widget.accent.withValues(alpha: 0.16),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ]
                    : const [],
              ),
              child: ContractGlassCard(
                padding: const EdgeInsets.all(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: enabled ? () async => widget.onTap!() : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: widget.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(widget.icon, color: widget.accent),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF5A5552),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.value,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1F262B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.detail,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6A6966),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MayoreoInsightGrid extends StatelessWidget {
  final List<_MayoreoPendingTask> tasks;
  final _MayoreoDashboardSummary summary;
  final Future<void> Function() onOpenPendingTasks;
  final Future<void> Function() onOpenCatalog;
  final Future<void> Function() onOpenPriceAdjustments;
  final Future<void> Function() onOpenAccounts;
  final Future<void> Function() onOpenSalesReports;
  final Future<void> Function() onOpenElPalomar;

  const _MayoreoInsightGrid({
    required this.tasks,
    required this.summary,
    required this.onOpenPendingTasks,
    required this.onOpenCatalog,
    required this.onOpenPriceAdjustments,
    required this.onOpenAccounts,
    required this.onOpenSalesReports,
    required this.onOpenElPalomar,
  });

  @override
  Widget build(BuildContext context) {
    final openTasks =
        <_MayoreoPendingTask>[
          ...summary.automaticPendingTasks,
          ...tasks.where((task) => !task.isDone),
        ]..sort((a, b) {
          if (a.dueDate != b.dueDate) return a.dueDate.compareTo(b.dueDate);
          if (a.isSystemGenerated != b.isSystemGenerated) {
            return a.isSystemGenerated ? -1 : 1;
          }
          return a.title.compareTo(b.title);
        });
    final palomarPriceItems = summary.palomarPrices.isEmpty
        ? [
            _DashboardListItem(
              label: 'Sin precios vigentes de El Palomar',
              value: 'CATALOGO',
              onTap: onOpenCatalog,
            ),
          ]
        : [
            for (final row in summary.palomarPrices)
              _DashboardListItem(
                label: row.materialName,
                value: _money(row.price),
                onTap: onOpenCatalog,
              ),
          ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 980;
        final topRow = stacked
            ? Column(
                children: [
                  _MayoreoInsightCard(
                    onTap: onOpenPendingTasks,
                    child: _MayoreoPendingPreviewBlock(tasks: openTasks),
                  ),
                  const SizedBox(height: 16),
                  _MayoreoInsightCard(
                    child: _PalomarPriceListBlock(
                      items: palomarPriceItems,
                      onOpenCatalog: onOpenCatalog,
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _MayoreoInsightCard(
                      onTap: onOpenPendingTasks,
                      child: _MayoreoPendingPreviewBlock(tasks: openTasks),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _MayoreoInsightCard(
                      child: _PalomarPriceListBlock(
                        items: palomarPriceItems,
                        onOpenCatalog: onOpenCatalog,
                      ),
                    ),
                  ),
                ],
              );
        return Column(
          children: [
            topRow,
            const SizedBox(height: 16),
            _MayoreoInsightCard(
              child: _DashboardListBlock(
                title: 'Resumen de origen',
                subtitle:
                    'Cada renglón te manda al módulo donde nace esa lectura.',
                items: [
                  _DashboardListItem(
                    label: 'Reportes pendientes por relacionar',
                    value: '${summary.pendingReportsCount}',
                    onTap: onOpenSalesReports,
                  ),
                  _DashboardListItem(
                    label: 'Cuentas abiertas por cobrar',
                    value: _money(
                      summary.pendingInvoiceAmount + summary.pendingCheckAmount,
                    ),
                    onTap: onOpenAccounts,
                  ),
                  _DashboardListItem(
                    label: 'Cobros vencidos por fecha estimada',
                    value:
                        '${summary.overdueEstimatedPaymentCount} · ${_money(summary.overdueEstimatedPaymentAmount)}',
                    onTap: onOpenAccounts,
                  ),
                  _DashboardListItem(
                    label: 'Saldo actual de El Palomar',
                    value: _money(summary.palomarBalance),
                    onTap: onOpenElPalomar,
                  ),
                  _DashboardListItem(
                    label: 'Remisiones disponibles para Palomar',
                    value: '${summary.availablePalomarRemissions}',
                    onTap: onOpenElPalomar,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MayoreoInsightCard extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onTap;

  const _MayoreoInsightCard({required this.child, this.onTap});

  @override
  State<_MayoreoInsightCard> createState() => _MayoreoInsightCardState();
}

class _MayoreoInsightCardState extends State<_MayoreoInsightCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: _hovered ? 1.004 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, _hovered ? -3.0 : 0.0, 0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: tokens.primaryStrong.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : const [],
            ),
            child: ContractGlassCard(
              padding: const EdgeInsets.all(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: widget.onTap == null
                    ? null
                    : () async => widget.onTap!(),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardListBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_DashboardListItem> items;

  const _DashboardListBlock({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: kMayoreoInk,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kMayoreoMutedInk,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DashboardListRow(item: item),
          ),
        ),
      ],
    );
  }
}

class _PalomarPriceListBlock extends StatefulWidget {
  final List<_DashboardListItem> items;
  final Future<void> Function() onOpenCatalog;

  const _PalomarPriceListBlock({
    required this.items,
    required this.onOpenCatalog,
  });

  @override
  State<_PalomarPriceListBlock> createState() => _PalomarPriceListBlockState();
}

class _PalomarPriceListBlockState extends State<_PalomarPriceListBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final visibleItems = _expanded
        ? widget.items
        : widget.items.take(6).toList(growable: false);
    final hasOverflow = widget.items.length > 6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lista de precios El Palomar',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: kMayoreoInk,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Verificación rápida de la lista vigente más urgente.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kMayoreoMutedInk,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        ...visibleItems.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DashboardListRow(item: item),
          ),
        ),
        if (hasOverflow)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded
                    ? Icons.unfold_less_rounded
                    : Icons.unfold_more_rounded,
              ),
              label: Text(_expanded ? 'Ver menos' : 'Ver más'),
            ),
          ),
      ],
    );
  }
}

class _DashboardListItem {
  final String label;
  final String value;
  final Future<void> Function()? onTap;

  const _DashboardListItem({
    required this.label,
    required this.value,
    this.onTap,
  });
}

class _DashboardListRow extends StatelessWidget {
  final _DashboardListItem item;

  const _DashboardListRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: item.onTap == null ? null : () async => item.onTap!(),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.88),
                tokens.badgeBackground.withValues(alpha: 0.70),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tokens.border.withValues(alpha: 0.84)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: kMayoreoInk,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                item.value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _money(num value) => formatMoney(value);

class _MayoreoDashboardSummary {
  final int pendingReportsCount;
  final int relatedReportsCount;
  final int pendingInvoiceCount;
  final double pendingInvoiceAmount;
  final int pendingCheckCount;
  final double pendingCheckAmount;
  final int accountsOpenCount;
  final double palomarBalance;
  final int palomarMovementCount;
  final int availablePalomarRemissions;
  final String palomarStatusLabel;
  final List<_MayoreoDashboardPriceRow> palomarPrices;
  final int overdueEstimatedPaymentCount;
  final double overdueEstimatedPaymentAmount;
  final List<_MayoreoPendingTask> automaticPendingTasks;

  const _MayoreoDashboardSummary({
    this.pendingReportsCount = 0,
    this.relatedReportsCount = 0,
    this.pendingInvoiceCount = 0,
    this.pendingInvoiceAmount = 0,
    this.pendingCheckCount = 0,
    this.pendingCheckAmount = 0,
    this.accountsOpenCount = 0,
    this.palomarBalance = 0,
    this.palomarMovementCount = 0,
    this.availablePalomarRemissions = 0,
    this.palomarStatusLabel = 'Sin movimientos',
    this.palomarPrices = const <_MayoreoDashboardPriceRow>[],
    this.overdueEstimatedPaymentCount = 0,
    this.overdueEstimatedPaymentAmount = 0,
    this.automaticPendingTasks = const <_MayoreoPendingTask>[],
  });

  String get priceAdjustmentsHint => 'CATALOGO';
}

_MayoreoDashboardSummary _buildDashboardSummary({
  required String? salesRaw,
  required String? accountsRaw,
  required String? palomarRaw,
  required MayoreoCatalogSnapshot catalogSnapshot,
}) {
  var pendingReportsCount = 0;
  var relatedReportsCount = 0;
  var pendingInvoiceCount = 0;
  var pendingInvoiceAmount = 0.0;
  var pendingCheckCount = 0;
  var pendingCheckAmount = 0.0;
  var accountsOpenCount = 0;
  var palomarBalance = 0.0;
  var palomarMovementCount = 0;
  var availablePalomarRemissions = 0;
  var overdueEstimatedPaymentCount = 0;
  var overdueEstimatedPaymentAmount = 0.0;
  final automaticPendingTasks = <_MayoreoPendingTask>[];
  final palomarCompanyIds = catalogSnapshot.companies
      .where(
        (row) => row.active && row.name.trim().toUpperCase() == 'EL PALOMAR',
      )
      .map((row) => row.id)
      .toSet();
  final materialsById = <String, MayoreoCatalogMaterialRecord>{
    for (final row in catalogSnapshot.materials) row.id: row,
  };
  final palomarPrices =
      catalogSnapshot.prices
          .where(
            (row) => row.active && palomarCompanyIds.contains(row.companyId),
          )
          .map((row) {
            final material = materialsById[row.materialId];
            if (material == null) return null;
            return _MayoreoDashboardPriceRow(
              materialName: material.name,
              price: row.amount,
            );
          })
          .whereType<_MayoreoDashboardPriceRow>()
          .toList(growable: false)
        ..sort((a, b) => a.materialName.compareTo(b.materialName));

  try {
    if (salesRaw != null && salesRaw.trim().isNotEmpty) {
      final data = jsonDecode(salesRaw) as Map<String, dynamic>;
      final rows = (data['rows'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item.cast<String, dynamic>()),
          )
          .toList(growable: false);
      for (final row in rows) {
        final approvedWeight = (row['approvedWeight'] as num?)?.toDouble();
        final approvedPrice = (row['approvedPrice'] as num?)?.toDouble();
        final isRelated =
            approvedWeight != null &&
            approvedPrice != null &&
            approvedWeight > 0;
        if (isRelated) {
          relatedReportsCount += 1;
          availablePalomarRemissions += 1;
        } else {
          pendingReportsCount += 1;
        }
      }
    }
  } catch (_) {}

  try {
    if (accountsRaw != null && accountsRaw.trim().isNotEmpty) {
      final data = jsonDecode(accountsRaw) as Map<String, dynamic>;
      final rows = (data['rows'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item.cast<String, dynamic>()),
          )
          .toList(growable: false);
      for (final row in rows) {
        final operationType = ((row['operationType'] as String?) ?? 'factura')
            .toLowerCase();
        final status = ((row['status'] as String?) ?? '').toLowerCase();
        final approvedAmount = ((row['approvedAmount'] as num?) ?? 0)
            .toDouble();
        final estimatedPaymentDate = DateTime.tryParse(
          (row['estimatedPaymentDate'] as String?) ?? '',
        );
        final isOpen =
            status != 'pagada' &&
            status != 'chequecanjeado' &&
            status != 'cancelada';
        if (!isOpen) continue;
        if (estimatedPaymentDate != null &&
            !DateUtils.dateOnly(
              estimatedPaymentDate,
            ).isAfter(DateUtils.dateOnly(DateTime.now()))) {
          overdueEstimatedPaymentCount += 1;
          overdueEstimatedPaymentAmount += approvedAmount;
          final clientName = ((row['clientName'] as String?) ?? '').trim();
          final documentNumber = ((row['documentNumber'] as String?) ?? '')
              .trim();
          final remision = ((row['remision'] as String?) ?? '').trim();
          final operationLabel = operationType == 'cheque'
              ? 'CHEQUE'
              : 'FACTURA';
          final pendingAmount =
              ((((row['approvedAmount'] as num?) ?? 0).toDouble()) -
                      (((row['paidAmount'] as num?) ?? 0).toDouble()))
                  .clamp(0, double.infinity);
          final detailParts = <String>[
            if (documentNumber.isNotEmpty)
              documentNumber
            else
              '$operationLabel SIN NUMERO',
            if (remision.isNotEmpty) 'REMISION $remision',
            _money(pendingAmount),
          ];
          automaticPendingTasks.add(
            _MayoreoPendingTask(
              id: 'auto_collection_${(row['id'] as String?) ?? documentNumber}_${estimatedPaymentDate.toIso8601String()}',
              title:
                  'Cobranza · ${clientName.isEmpty ? 'CUENTA ABIERTA' : clientName}',
              dueDate: DateUtils.dateOnly(estimatedPaymentDate),
              source: 'COBRANZA',
              isDone: false,
              detail: detailParts.join(' · '),
              isSystemGenerated: true,
            ),
          );
        }
        accountsOpenCount += 1;
        if (operationType == 'cheque') {
          pendingCheckCount += 1;
          pendingCheckAmount += approvedAmount;
        } else {
          pendingInvoiceCount += 1;
          pendingInvoiceAmount += approvedAmount;
        }
      }
    }
  } catch (_) {}

  try {
    if (palomarRaw != null && palomarRaw.trim().isNotEmpty) {
      final data = jsonDecode(palomarRaw) as Map<String, dynamic>;
      final movements =
          (data['movements'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map(
                (item) =>
                    Map<String, dynamic>.from(item.cast<String, dynamic>()),
              )
              .toList(growable: false);
      palomarMovementCount = movements.length;
      for (final movement in movements) {
        final type = ((movement['type'] as String?) ?? '').toLowerCase();
        final amount = ((movement['amount'] as num?) ?? 0).toDouble();
        switch (type) {
          case 'chequeliberado':
          case 'ajustecargo':
            palomarBalance += amount;
            break;
          case 'remisionaplicada':
          case 'ajusteabono':
            palomarBalance -= amount;
            final sourceId = (movement['sourceReportId'] as String?) ?? '';
            if (sourceId.isNotEmpty && availablePalomarRemissions > 0) {
              availablePalomarRemissions -= 1;
            }
            break;
          default:
            break;
        }
      }
    }
  } catch (_) {}

  final palomarStatusLabel = palomarBalance <= 0
      ? 'Cuenta cubierta'
      : palomarBalance >= 500000
      ? 'Saldo alto pendiente'
      : 'Operativa';

  return _MayoreoDashboardSummary(
    pendingReportsCount: pendingReportsCount,
    relatedReportsCount: relatedReportsCount,
    pendingInvoiceCount: pendingInvoiceCount,
    pendingInvoiceAmount: pendingInvoiceAmount,
    pendingCheckCount: pendingCheckCount,
    pendingCheckAmount: pendingCheckAmount,
    accountsOpenCount: accountsOpenCount,
    palomarBalance: palomarBalance,
    palomarMovementCount: palomarMovementCount,
    availablePalomarRemissions: availablePalomarRemissions,
    palomarStatusLabel: palomarStatusLabel,
    palomarPrices: palomarPrices,
    overdueEstimatedPaymentCount: overdueEstimatedPaymentCount,
    overdueEstimatedPaymentAmount: overdueEstimatedPaymentAmount,
    automaticPendingTasks: automaticPendingTasks,
  );
}

class _MayoreoDashboardPriceRow {
  final String materialName;
  final double price;

  const _MayoreoDashboardPriceRow({
    required this.materialName,
    required this.price,
  });
}

class _MayoreoPendingPreviewBlock extends StatelessWidget {
  final List<_MayoreoPendingTask> tasks;

  const _MayoreoPendingPreviewBlock({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final preview = tasks.take(4).toList(growable: false);
    final automaticCount = tasks.where((task) => task.isSystemGenerated).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pendientes por atender',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: kMayoreoInk,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tasks.isEmpty
              ? 'No hay pendientes activos. Usa el botón superior para capturar tareas nuevas.'
              : automaticCount > 0
              ? '${tasks.length} pendientes abiertos, incluidos $automaticCount recordatorios automáticos de cobranza.'
              : '${tasks.length} pendientes abiertos capturados por Dirección o Ventas.',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kMayoreoMutedInk,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        if (preview.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.88),
                  mayoreoAreaTokens.badgeBackground.withValues(alpha: 0.70),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: mayoreoAreaTokens.border.withValues(alpha: 0.84),
              ),
            ),
            child: const Text(
              'Sin pendientes activos.',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: kMayoreoInk,
              ),
            ),
          )
        else
          ...preview.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MayoreoPendingPreviewRow(task: task),
            ),
          ),
      ],
    );
  }
}

class _MayoreoPendingPreviewRow extends StatelessWidget {
  final _MayoreoPendingTask task;

  const _MayoreoPendingPreviewRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final accent = task.source == 'COBRANZA'
        ? const Color(0xFFB4543D)
        : task.source == 'DIRECCION'
        ? const Color(0xFFC78A00)
        : tokens.primaryStrong;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.88),
            tokens.badgeBackground.withValues(alpha: 0.70),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.border.withValues(alpha: 0.84)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: kMayoreoInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${task.source} · ${_formatDashboardDate(task.dueDate)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kMayoreoMutedInk,
                  ),
                ),
                if (task.detail.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: kMayoreoMutedInk,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MayoreoPendingTasksDialog extends StatefulWidget {
  final List<_MayoreoPendingTask> initialTasks;
  final List<_MayoreoPendingTask> automaticTasks;
  final String defaultSource;

  const _MayoreoPendingTasksDialog({
    required this.initialTasks,
    required this.automaticTasks,
    required this.defaultSource,
  });

  @override
  State<_MayoreoPendingTasksDialog> createState() =>
      _MayoreoPendingTasksDialogState();
}

class _MayoreoPendingTasksDialogState
    extends State<_MayoreoPendingTasksDialog> {
  late final TextEditingController _titleC;
  late List<_MayoreoPendingTask> _tasks;
  late String _source;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleC = TextEditingController();
    _tasks = widget.initialTasks.toList(growable: true);
    _source = widget.defaultSource;
  }

  @override
  void dispose() {
    _titleC.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: mayoreoAreaTokens.primaryStrong,
            onPrimary: Colors.white,
            surface: mayoreoAreaTokens.surfaceTint,
            onSurface: kMayoreoInk,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _dueDate = picked);
  }

  void _addTask() {
    final title = _titleC.text.trim();
    if (title.isEmpty || _dueDate == null) return;
    setState(() {
      _tasks = <_MayoreoPendingTask>[
        _MayoreoPendingTask(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title,
          dueDate: _dueDate!,
          source: _source,
          isDone: false,
        ),
        ..._tasks,
      ];
      _titleC.clear();
      _dueDate = null;
      _source = widget.defaultSource;
    });
  }

  void _toggleTask(String id) {
    setState(() {
      _tasks = _tasks
          .map(
            (task) =>
                task.id == id ? task.copyWith(isDone: !task.isDone) : task,
          )
          .toList(growable: false);
    });
  }

  void _removeTask(String id) {
    setState(() {
      _tasks = _tasks.where((task) => task.id != id).toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final automaticTasks = widget.automaticTasks.toList(growable: false)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final manualOpenTasks = _tasks.where((task) => !task.isDone).length;
    final openTasks = automaticTasks.length + manualOpenTasks;
    final doneTasks = _tasks.length - manualOpenTasks;
    final sortedTasks = _tasks.toList(growable: false)
      ..sort((a, b) {
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        return a.dueDate.compareTo(b.dueDate);
      });

    return ContractDialogShell(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _PendingTitleBlock(
                      title: 'Pendientes',
                      subtitle:
                          'Lista operativa compartida entre Dirección y Ventas.',
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(_tasks),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PendingSummaryCard(
                      label: 'Abiertos',
                      value: '$openTasks',
                      icon: Icons.pending_actions_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PendingSummaryCard(
                      label: 'Hechos',
                      value: '${doneTasks.clamp(0, _tasks.length)}',
                      icon: Icons.task_alt_rounded,
                    ),
                  ),
                  if (automaticTasks.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PendingSummaryCard(
                        label: 'Cobranza',
                        value: '${automaticTasks.length}',
                        icon: Icons.notifications_active_outlined,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              ContractGlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nuevo pendiente',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: kMayoreoInk,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _titleC,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Escribe el pendiente',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: mayoreoAreaTokens.primaryStrong,
                              side: BorderSide(color: mayoreoAreaTokens.border),
                              minimumSize: const Size.fromHeight(44),
                            ),
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_month_rounded),
                            label: Text(
                              _dueDate == null
                                  ? 'Fecha'
                                  : _formatDashboardDate(_dueDate!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'DIRECCION',
                              label: Text('Dirección'),
                            ),
                            ButtonSegment<String>(
                              value: 'VENTAS',
                              label: Text('Ventas'),
                            ),
                          ],
                          selected: <String>{_source},
                          onSelectionChanged: (next) {
                            setState(() => _source = next.first);
                          },
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: mayoreoAreaTokens.primaryStrong,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 44),
                          ),
                          onPressed:
                              _titleC.text.trim().isEmpty || _dueDate == null
                              ? null
                              : _addTask,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Agregar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ContractGlassCard(
                  padding: const EdgeInsets.all(14),
                  child: automaticTasks.isEmpty && sortedTasks.isEmpty
                      ? const Center(
                          child: Text(
                            'Todavía no hay pendientes capturados.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kMayoreoMutedInk,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: automaticTasks.length + sortedTasks.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final task = index < automaticTasks.length
                                ? automaticTasks[index]
                                : sortedTasks[index - automaticTasks.length];
                            return _PendingTaskRow(
                              task: task,
                              onToggleDone: task.isSystemGenerated
                                  ? null
                                  : () => _toggleTask(task.id),
                              onDelete: task.isSystemGenerated
                                  ? null
                                  : () => _removeTask(task.id),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: mayoreoAreaTokens.primaryStrong,
                      side: BorderSide(color: mayoreoAreaTokens.border),
                    ),
                    onPressed: () => Navigator.of(context).pop(_tasks),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cerrar'),
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

class _PendingTitleBlock extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PendingTitleBlock({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: kMayoreoHeroGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: mayoreoAreaTokens.primaryStrong.withValues(alpha: 0.18),
            ),
          ),
          child: Icon(
            Icons.notifications_none_rounded,
            color: mayoreoAreaTokens.primaryStrong,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: kMayoreoInk,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kMayoreoMutedInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PendingSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _PendingSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: kMayoreoPanelGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: mayoreoAreaTokens.border.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: mayoreoAreaTokens.primaryStrong),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingTaskRow extends StatelessWidget {
  final _MayoreoPendingTask task;
  final VoidCallback? onToggleDone;
  final VoidCallback? onDelete;

  const _PendingTaskRow({
    required this.task,
    required this.onToggleDone,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = task.source == 'COBRANZA'
        ? const Color(0xFFB4543D)
        : task.source == 'DIRECCION'
        ? const Color(0xFFC78A00)
        : mayoreoAreaTokens.primaryStrong;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: mayoreoAreaTokens.border.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        children: [
          if (task.isSystemGenerated)
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.16),
                border: Border.all(color: accent, width: 1.4),
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                size: 14,
                color: accent,
              ),
            )
          else
            InkWell(
              onTap: onToggleDone,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.isDone
                      ? accent.withValues(alpha: 0.18)
                      : Colors.transparent,
                  border: Border.all(color: accent, width: 1.4),
                ),
                child: task.isDone
                    ? Icon(Icons.check_rounded, size: 16, color: accent)
                    : null,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kMayoreoInk,
                    decoration: task.isDone
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${task.source} · ${_formatDashboardDate(task.dueDate)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kMayoreoMutedInk,
                  ),
                ),
                if (task.detail.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.detail,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kMayoreoMutedInk,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (task.isSystemGenerated)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withValues(alpha: 0.24)),
              ),
              child: Text(
                'AUTO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: accent,
                ),
              ),
            )
          else
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              color: kMayoreoMutedInk,
            ),
        ],
      ),
    );
  }
}

class _MayoreoPendingTask {
  final String id;
  final String title;
  final DateTime dueDate;
  final String source;
  final bool isDone;
  final String detail;
  final bool isSystemGenerated;

  const _MayoreoPendingTask({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.source,
    required this.isDone,
    this.detail = '',
    this.isSystemGenerated = false,
  });

  _MayoreoPendingTask copyWith({
    String? id,
    String? title,
    DateTime? dueDate,
    String? source,
    bool? isDone,
    String? detail,
    bool? isSystemGenerated,
  }) {
    return _MayoreoPendingTask(
      id: id ?? this.id,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      source: source ?? this.source,
      isDone: isDone ?? this.isDone,
      detail: detail ?? this.detail,
      isSystemGenerated: isSystemGenerated ?? this.isSystemGenerated,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'dueDate': dueDate.toIso8601String(),
    'source': source,
    'isDone': isDone,
    'detail': detail,
    'isSystemGenerated': isSystemGenerated,
  };

  Map<String, dynamic> toSupabase() => <String, dynamic>{
    'id': id,
    'title': title,
    'due_date': dueDate.toIso8601String(),
    'source': source,
    'is_done': isDone,
    'detail': detail.isEmpty ? null : detail,
    'is_system_generated': isSystemGenerated,
  };

  factory _MayoreoPendingTask.fromSupabase(Map<String, dynamic> json) {
    return _MayoreoPendingTask(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      dueDate:
          DateTime.tryParse((json['due_date'] as String?) ?? '') ??
          DateTime.now(),
      source: ((json['source'] as String?) ?? 'VENTAS').toUpperCase(),
      isDone: json['is_done'] == true,
      detail: (json['detail'] as String?) ?? '',
      isSystemGenerated: json['is_system_generated'] == true,
    );
  }
}

String _formatDashboardDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}

class _MayoreoHeaderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function()? onTap;
  final VoidCallback? onTapSync;
  final int notificationCount;
  final bool compact;

  const _MayoreoHeaderButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.onTapSync,
    this.notificationCount = 0,
    this.compact = false,
  });

  @override
  State<_MayoreoHeaderButton> createState() => _MayoreoHeaderButtonState();
}

class _MayoreoHeaderButtonState extends State<_MayoreoHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final enabled = widget.onTap != null || widget.onTapSync != null;
    final highlighted = enabled && _hovered;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: highlighted ? 1.026 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            onTap: !enabled
                ? null
                : () async {
                    if (widget.onTap != null) {
                      await widget.onTap!();
                    } else {
                      widget.onTapSync?.call();
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(
                0,
                highlighted ? -2.5 : 0,
                0,
              ),
              width: widget.compact ? 56 : 176,
              height: 56,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 0 : 20,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: highlighted ? 0.32 : 0.22),
                    tokens.surfaceTint.withValues(
                      alpha: highlighted ? 0.42 : 0.26,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: highlighted
                      ? Colors.white.withValues(alpha: 0.76)
                      : Colors.white.withValues(alpha: 0.48),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: highlighted ? 28 : 16,
                    color: Colors.black.withValues(
                      alpha: highlighted ? 0.16 : 0.08,
                    ),
                    offset: Offset(0, highlighted ? 14 : 8),
                  ),
                  BoxShadow(
                    blurRadius: highlighted ? 20 : 10,
                    color: tokens.glow.withValues(
                      alpha: highlighted ? 0.12 : 0.05,
                    ),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: widget.compact
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      Icon(widget.icon, size: 20, color: tokens.primaryStrong),
                      if (!widget.compact) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                color: tokens.primaryStrong,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (widget.notificationCount > 0)
                    Positioned(
                      right: -6,
                      top: -8,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD92D20),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.92),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 12,
                              color: const Color(
                                0xFFD92D20,
                              ).withValues(alpha: 0.26),
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.notificationCount > 9
                                ? '9+'
                                : '${widget.notificationCount}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
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
  }
}

class _MayoreoSidePanel extends StatelessWidget {
  final bool canReturnToDirection;
  final ValueChanged<String> onNavigate;

  const _MayoreoSidePanel({
    required this.canReturnToDirection,
    required this.onNavigate,
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
                'Mayoreo',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: tokens.primaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              if (canReturnToDirection) ...[
                _MayoreoNavItem(
                  icon: Icons.arrow_back_rounded,
                  title: 'Volver a Dirección',
                  onTapSync: () => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 10),
              ],
              const _MayoreoSectionHeader(label: 'MENU'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.primarySoft.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: tokens.primaryStrong.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  children: [
                    _MayoreoNavItem(
                      icon: Icons.point_of_sale_rounded,
                      title: 'Ventas',
                      subtitle: 'Seguimiento de pedidos y cierre',
                      onTapSync: () => onNavigate('Ventas Mayoreo'),
                    ),
                    const SizedBox(height: 8),
                    _MayoreoNavItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Cuentas',
                      subtitle: 'Facturas, cheques y cobranza',
                      onTapSync: () => onNavigate('Cuentas'),
                    ),
                    const SizedBox(height: 8),
                    _MayoreoNavItem(
                      icon: Icons.currency_exchange_rounded,
                      title: 'Cuenta El Palomar',
                      subtitle: 'Cuenta corriente especial',
                      onTapSync: () => onNavigate('Cuenta El Palomar'),
                    ),
                    const SizedBox(height: 8),
                    _MayoreoNavItem(
                      icon: Icons.price_check_rounded,
                      title: 'Catálogo',
                      subtitle: 'Empresas, materiales y precios',
                      onTapSync: () => onNavigate('Catálogo'),
                    ),
                    const SizedBox(height: 8),
                    _MayoreoNavItem(
                      icon: Icons.request_quote_rounded,
                      title: 'Ajuste de precios',
                      subtitle: 'Listas, vigentes y ajustes',
                      onTapSync: () => onNavigate('Ajuste de precios'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _MayoreoSectionHeader(label: 'ACCESOS'),
              const SizedBox(height: 8),
              if (canReturnToDirection) ...[
                _MayoreoNavItem(
                  icon: Icons.assessment_outlined,
                  title: 'Dashboard Dirección',
                  subtitle: 'Vista ejecutiva multiarea',
                  onTapSync: () => onNavigate('Dashboard Dirección'),
                ),
                const SizedBox(height: 8),
              ],
              const _MayoreoNavItem(
                icon: Icons.space_dashboard_rounded,
                title: 'Dashboard Mayoreo',
                subtitle: 'Vista general del área',
                accented: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MayoreoSectionHeader extends StatelessWidget {
  final String label;

  const _MayoreoSectionHeader({required this.label});

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

class _MayoreoNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool accented;
  final VoidCallback? onTapSync;

  const _MayoreoNavItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.accented = false,
    this.onTapSync,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AreaThemeScope.of(context);
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTapSync,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: accented ? kMayoreoHeroGradient : kMayoreoPanelGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accented
                    ? Colors.white.withValues(alpha: 0.72)
                    : Colors.white.withValues(alpha: 0.58),
              ),
              boxShadow: accented
                  ? [
                      BoxShadow(
                        color: mayoreoAreaTokens.glow.withValues(alpha: 0.20),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: accented ? Colors.white : tokens.primaryStrong,
                  size: 22,
                ),
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
                          color: accented ? Colors.white : tokens.primaryStrong,
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
                                : tokens.badgeText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!accented) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: tokens.badgeText,
                    size: 22,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
