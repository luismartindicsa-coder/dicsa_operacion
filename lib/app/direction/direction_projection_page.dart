import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dashboard/general_dashboard_page.dart';
import '../shared/app_shell.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'direction_shipments_page.dart';
import 'direction_shipments_store.dart';
import 'direction_theme.dart';
import 'expected_income/expected_income_view.dart';
import 'projection/weekly_projection_view.dart';

/// Hybrid tabs (Almacén archetype), cloned from Dirección / Embarques:
/// shared Dirección shell, header, overlay navigation, week and silent refresh.
class DirectionProjectionPage extends StatefulWidget {
  final bool instantOpen;
  final DateTime? initialWeekStartDate;
  const DirectionProjectionPage({
    super.key,
    this.instantOpen = false,
    this.initialWeekStartDate,
  });
  @override
  State<DirectionProjectionPage> createState() =>
      _DirectionProjectionPageState();
}

class _DirectionProjectionPageState extends State<DirectionProjectionPage> {
  bool _menuOpen = false, _loading = false;
  int _selectedTab = 0, _request = 0;
  String? _error;
  late DateTime _week;
  DirectionShipmentPlanningBundle? _bundle;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _week = DirectionShipmentsStore.normalizeWeekStartDate(
      widget.initialWeekStartDate ??
          DirectionShipmentsStore.currentWeekStartDate(),
    );
    unawaited(_load());
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_load()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _request++;
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    final request = ++_request;
    final week = _week;
    try {
      final bundle = await DirectionShipmentsStore.loadWeek(week);
      if (!mounted || request != _request) return;
      setState(() {
        _bundle = bundle;
        _error = null;
      });
    } catch (e) {
      if (mounted && request == _request) {
        setState(() => _error = 'No se pudo actualizar la semana: $e');
      }
    } finally {
      if (request == _request) _loading = false;
    }
  }

  Future<void> _changeWeek(DateTime week) async {
    setState(() {
      _week = DirectionShipmentsStore.normalizeWeekStartDate(week);
      _bundle = null;
      _error = null;
      _request++;
      _loading = false;
    });
    await _load();
  }

  Future<void> _openDashboard() async => Navigator.of(context).pushReplacement(
    appPageRoute(page: const GeneralDashboardPage(instantOpen: true)),
  );
  Future<void> _openShipments() async => Navigator.of(context).pushReplacement(
    appPageRoute(
      page: DirectionShipmentsPage(
        instantOpen: true,
        initialWeekStartDate: _week,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => AreaThemeScope(
    tokens: directionAreaTokens,
    child: Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            _menuOpen) {
          setState(() => _menuOpen = false);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AppShell(
        background: const DirectionExecutiveBackground(),
        wrapBodyInGlass: false,
        animateHeaderSlots: false,
        animateBody: !widget.instantOpen,
        headerBodySpacing: 8,
        padding: const EdgeInsets.fromLTRB(28, 14, 18, 18),
        leadingBuilder: (_, _) => DirectionHeaderButton(
          label: _menuOpen ? 'Cerrar panel' : 'Navegación',
          icon: _menuOpen ? Icons.close_rounded : Icons.menu_rounded,
          onTapSync: () => setState(() => _menuOpen = !_menuOpen),
        ),
        centerBuilder: (_, animation) =>
            DirectionHeaderBrand(contentAnim: animation, title: 'Proyección'),
        trailingBuilder: (_, _) => DirectionHeaderButton(
          label: 'Dashboard',
          icon: Icons.space_dashboard_rounded,
          onTap: _openDashboard,
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1460),
                child: Padding(
                  padding: const EdgeInsets.only(left: 56, right: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(
                              value: 0,
                              label: Text('Ingresos'),
                              icon: Icon(Icons.payments_outlined),
                            ),
                            ButtonSegment(
                              value: 1,
                              label: Text('Egresos'),
                              icon: Icon(Icons.receipt_long_outlined),
                            ),
                            ButtonSegment(
                              value: 2,
                              label: Text('Flujo semanal proyectado'),
                              icon: Icon(Icons.account_balance_wallet_outlined),
                            ),
                          ],
                          selected: {_selectedTab},
                          onSelectionChanged: (v) =>
                              setState(() => _selectedTab = v.single),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: kDirectionDanger),
                          ),
                        ),
                      Expanded(
                        child: _bundle == null
                            ? Center(
                                child: _error == null
                                    ? const CircularProgressIndicator()
                                    : const Text(
                                        'Reintentando actualización automáticamente…',
                                      ),
                              )
                            : IndexedStack(
                                index: _selectedTab == 0 ? 0 : 1,
                                children: [
                                  ExpectedIncomeView(
                                    bundle: _bundle!,
                                    referenceError: _error,
                                    onWeekChanged: _changeWeek,
                                    active: _selectedTab == 0 && _error == null,
                                  ),
                                  WeeklyProjectionView(
                                    bundle: _bundle!,
                                    referenceError: _error,
                                    onWeekChanged: _changeWeek,
                                    active: _selectedTab != 0 && _error == null,
                                    flow: _selectedTab == 2,
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: _menuOpen ? 0 : -332,
              top: 0,
              width: 320,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !_menuOpen,
                child: SingleChildScrollView(
                  child: DirectionModuleMenuPanel(
                    entries: [
                      DirectionModuleMenuEntry(
                        icon: Icons.space_dashboard_rounded,
                        title: 'Dashboard Dirección',
                        subtitle: 'Resumen ejecutivo principal',
                        onTap: _openDashboard,
                      ),
                      DirectionModuleMenuEntry(
                        icon: Icons.local_shipping_rounded,
                        title: 'Embarques',
                        subtitle: 'Embarques y programa operativo',
                        onTap: _openShipments,
                      ),
                      const DirectionModuleMenuEntry(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Proyección',
                        subtitle: 'Ingresos, egresos y flujo semanal',
                        current: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
