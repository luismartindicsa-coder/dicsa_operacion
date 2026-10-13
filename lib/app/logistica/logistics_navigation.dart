import 'package:flutter/material.dart';
import '../dashboard/general_dashboard_page.dart';
import 'logistics_area_chrome.dart';
import 'logistics_dashboard_page.dart';
import 'logistics_control_daily_page.dart';
import 'logistics_catalog_page.dart';
import 'logistics_diesel_page.dart';
import 'logistics_gasoline_page.dart';
import 'logistics_performance_page.dart';
import 'logistics_savings_page.dart';
import 'logistics_operations_pages.dart';

Widget? logisticsPageFor(String label) => switch (label) {
  kLogisticsNavDashboardLabel => const LogisticsDashboardPage(
    instantOpen: true,
  ),
  kLogisticsNavControlDailyLabel => const LogisticsControlDailyPage(),
  kLogisticsNavFleetStatusLabel => const LogisticsUnitsPage(),
  kLogisticsNavIncidentsLabel => const LogisticsIncidentsPage(),
  kLogisticsNavCatalogsLabel => const LogisticsCatalogPage(),
  kLogisticsNavDieselLabel => const LogisticsDieselPage(),
  kLogisticsNavGasolineLabel => const LogisticsGasolinePage(),
  kLogisticsNavPerformanceLabel => const LogisticsPerformancePage(),
  kLogisticsNavSavingsLabel => const LogisticsSavingsPage(),
  kLogisticsNavDirectionDashboardLabel => const GeneralDashboardPage(
    instantOpen: true,
  ),
  _ => null,
};
