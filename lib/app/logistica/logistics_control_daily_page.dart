import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_access.dart';
import '../dashboard/general_dashboard_page.dart';
import '../services/services_page.dart';
import '../shared/page_routes.dart';
import 'logistics_area_chrome.dart';
import 'logistics_catalog_page.dart';
import 'logistics_dashboard_page.dart';

class LogisticsControlDailyPage extends StatefulWidget {
  const LogisticsControlDailyPage({super.key});

  @override
  State<LogisticsControlDailyPage> createState() =>
      _LogisticsControlDailyPageState();
}

class _LogisticsControlDailyPageState extends State<LogisticsControlDailyPage> {
  bool _canReturnToDirection = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveNavigationAccess());
  }

  Future<void> _resolveNavigationAccess() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    setState(() {
      _canReturnToDirection = AuthAccess.isDirectionRole(profile);
    });
  }

  Future<void> _openLogisticsDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const LogisticsDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _openDirectionDashboard() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const GeneralDashboardPage(instantOpen: true),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  Future<void> _openCatalogs() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      appPageRoute(
        page: const LogisticsCatalogPage(),
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  void _showPhaseSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _handleNavigationAction(String label) {
    switch (label) {
      case kLogisticsNavDashboardLabel:
        unawaited(_openLogisticsDashboard());
        return;
      case kLogisticsNavControlDailyLabel:
        return;
      case kLogisticsNavFleetStatusLabel:
        _showPhaseSnack(
          'Estado de Unidades se abrirá en la siguiente fase del área.',
        );
        return;
      case kLogisticsNavCatalogsLabel:
        unawaited(_openCatalogs());
        return;
      case kLogisticsNavIncidentsLabel:
        _showPhaseSnack(
          'Incidencias se habilitará cuando quede validado el flujo base.',
        );
        return;
      case kLogisticsNavSavingsLabel:
        _showPhaseSnack(
          'Ahorro y Planeación se conectará después del Control Diario.',
        );
        return;
      case kLogisticsNavDirectionDashboardLabel:
        unawaited(_openDirectionDashboard());
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ServicesPage(
      headerTitle: 'Control Diario de Logística',
      servicesNavLabel: kLogisticsNavControlDailyLabel,
      logisticsSilverMode: true,
      showLogisticsPlanningTopContent: false,
      sideMenuWidth: kLogisticsSideMenuWidth,
      customSideMenuBuilder: (context, closeMenu) => LogisticsAreaSidePanel(
        currentLabel: kLogisticsNavControlDailyLabel,
        canReturnToDirection: _canReturnToDirection,
        onNavigate: (label) {
          closeMenu();
          _handleNavigationAction(label);
        },
      ),
    );
  }
}
