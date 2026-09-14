import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_access.dart';
import '../auth/auth_navigation.dart';
import '../dashboard/general_dashboard_page.dart';
import '../services/services_shell.dart';
import '../services/services_visual_mode.dart';
import '../shared/page_routes.dart';
import '../shared/ui_contract_core/theme/area_theme_scope.dart';
import 'logistics_area_chrome.dart';
import 'logistics_catalog_page.dart';
import 'logistics_control_daily_page.dart';
import 'logistics_dashboard_page.dart';
import 'logistics_diesel_page.dart';
import 'logistics_gasoline_page.dart';
import 'logistics_performance_page.dart';
import 'logistics_company_profile_store.dart';
import 'logistics_theme.dart';
import 'logistics_zone_store.dart';

class LogisticsSavingsPage extends StatefulWidget {
  const LogisticsSavingsPage({super.key});

  @override
  State<LogisticsSavingsPage> createState() => _LogisticsSavingsPageState();
}

class _LogisticsSavingsPageState extends State<LogisticsSavingsPage> {
  bool _loading = true;
  bool _canReturnToDirection = false;
  String? _error;
  List<LogisticsCompanyProfileRecord> _companies = const [];
  List<LogisticsZoneRecord> _zones = const [];
  List<Map<String, dynamic>> _serviceRows = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        AuthAccess.resolveCurrentProfile(),
        LogisticsCompanyProfileStore.loadProfiles(),
        LogisticsZoneStore.loadZones(),
        _loadUpcomingServices(),
      ]);
      if (!mounted) return;
      setState(() {
        _canReturnToDirection = AuthAccess.isDirectionRole(results[0]);
        _companies = (results[1] as List).cast<LogisticsCompanyProfileRecord>();
        _zones = (results[2] as List).cast<LogisticsZoneRecord>();
        _serviceRows = results[3] as List<Map<String, dynamic>>;
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

  Future<List<Map<String, dynamic>>> _loadUpcomingServices() async {
    try {
      final today = DateUtils.dateOnly(DateTime.now());
      final end = today.add(const Duration(days: 7));
      final data = await Supabase.instance.client
          .from('v_services_grid')
          .select('*')
          .gte(
            'due_date',
            '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
          )
          .lte(
            'due_date',
            '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}',
          )
          .limit(500);
      return (data as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _go(Widget page) =>
      Navigator.of(context).pushReplacement(appPageRoute(page: page));

  void _navigate(String label) {
    switch (label) {
      case kLogisticsNavDashboardLabel:
        unawaited(_go(const LogisticsDashboardPage(instantOpen: true)));
        return;
      case kLogisticsNavControlDailyLabel:
        unawaited(_go(const LogisticsControlDailyPage()));
        return;
      case kLogisticsNavCatalogsLabel:
        unawaited(_go(const LogisticsCatalogPage()));
        return;
      case kLogisticsNavDieselLabel:
        unawaited(_go(const LogisticsDieselPage()));
        return;
      case kLogisticsNavGasolineLabel:
        unawaited(_go(const LogisticsGasolinePage()));
        return;
      case kLogisticsNavPerformanceLabel:
        unawaited(_go(const LogisticsPerformancePage()));
        return;
      case kLogisticsNavDirectionDashboardLabel:
        unawaited(_go(const GeneralDashboardPage(instantOpen: true)));
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este módulo se habilitará en la siguiente fase.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => ServicesVisualModeScope(
    logisticsSilverMode: true,
    child: AreaThemeScope(
      tokens: logisticsAreaTokens,
      child: ServicesShell(
        headerTitle: 'Ahorro y Planeación',
        servicesNavLabel: kLogisticsNavSavingsLabel,
        sideMenuWidth: kLogisticsSideMenuWidth,
        customSideMenuBuilder: (context, closeMenu) => LogisticsAreaSidePanel(
          currentLabel: kLogisticsNavSavingsLabel,
          canReturnToDirection: _canReturnToDirection,
          onNavigate: (label) {
            closeMenu();
            _navigate(label);
          },
        ),
        onLogout: () async => signOutAndRouteToLogin(context),
        onGoToGeneralDashboard: () =>
            _go(const GeneralDashboardPage(instantOpen: true)),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text('No se pudo cargar la planeación: $_error'))
            : _content(),
      ),
    ),
  );

  Widget _content() {
    final located = _companies
        .where((c) => c.latitude != null && c.longitude != null)
        .length;
    final unzoned = _companies
        .where(
          (c) =>
              c.latitude != null &&
              c.longitude != null &&
              (c.zoneId ?? '').isEmpty,
        )
        .length;
    final activeZones = _zones.where((z) => z.active).toList();
    final assigned = _companies
        .where((c) => (c.zoneId ?? '').isNotEmpty)
        .length;
    final suggestions = _buildSuggestions();
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SavingsMetric(
                'Empresas ubicadas',
                '$located',
                Icons.place_rounded,
              ),
              _SavingsMetric(
                'Zonas activas',
                '${activeZones.length}',
                Icons.grid_view_rounded,
              ),
              _SavingsMetric(
                'Empresas zonificadas',
                '$assigned',
                Icons.route_rounded,
              ),
              _SavingsMetric(
                'Pendientes de zona',
                '$unzoned',
                Icons.warning_amber_rounded,
              ),
              _SavingsMetric(
                'Servicios próximos',
                '${_serviceRows.length}',
                Icons.event_available_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: kLogisticsPanelGradient,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: kLogisticsSilverBorder),
              ),
              child: ListView(
                children: [
                  const Text(
                    'Oportunidades de ahorro',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: kLogisticsSilverTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    suggestions.isEmpty
                        ? 'No hay agrupaciones sugeribles en los próximos siete días todavía. La lectura se actualizará al programar servicios.'
                        : '${suggestions.length} sugerencia(s) generadas al cruzar programación próxima con zonas y empresas.',
                    style: TextStyle(
                      color: kLogisticsSilverTextSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (var index = 0; index < suggestions.length; index++) ...[
                    _SavingsAction(
                      icon: suggestions[index].icon,
                      title: suggestions[index].title,
                      detail: suggestions[index].detail,
                      action: suggestions[index].catalog
                          ? 'Abrir mapa y zonas'
                          : 'Abrir Control Diario',
                      onTap: () => unawaited(
                        _go(
                          suggestions[index].catalog
                              ? const LogisticsCatalogPage()
                              : const LogisticsControlDailyPage(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_SavingsSuggestion> _buildSuggestions() {
    final companyByName = <String, LogisticsCompanyProfileRecord>{
      for (final company in _companies)
        company.siteName.trim().toUpperCase(): company,
    };
    final zoneById = <String, LogisticsZoneRecord>{
      for (final zone in _zones) zone.id: zone,
    };
    final grouped = <String, List<String>>{};
    final unzonedCompanies = <String>{};
    for (final row in _serviceRows) {
      final companyName = (row['client_name'] ?? row['client_label'] ?? '')
          .toString()
          .trim();
      final company = companyByName[companyName.toUpperCase()];
      if (company == null) continue;
      final zoneId = (company.zoneId ?? '').trim();
      if (zoneId.isEmpty) {
        unzonedCompanies.add(company.siteName);
        continue;
      }
      final date = (row['due_date'] ?? '').toString().split('T').first;
      grouped
          .putIfAbsent('$date|$zoneId', () => <String>[])
          .add(company.siteName);
    }
    final suggestions = <_SavingsSuggestion>[];
    if (unzonedCompanies.isNotEmpty) {
      suggestions.add(
        _SavingsSuggestion(
          icon: Icons.map_outlined,
          title: '${unzonedCompanies.length} empresa(s) programadas sin zona',
          detail:
              '${unzonedCompanies.take(4).join(', ')}${unzonedCompanies.length > 4 ? ' y más' : ''}. Asígnalas antes de combinar recorridos.',
          catalog: true,
        ),
      );
    }
    for (final entry in grouped.entries) {
      if (entry.value.length < 2) continue;
      final parts = entry.key.split('|');
      final zone = zoneById[parts[1]];
      if (zone == null) continue;
      final companies = entry.value.toSet().toList();
      suggestions.add(
        _SavingsSuggestion(
          icon: Icons.merge_type_rounded,
          title:
              '${entry.value.length} servicios en ${zone.code} el ${parts.first}',
          detail:
              'Revisar una ruta combinada para ${companies.take(4).join(', ')}${companies.length > 4 ? ' y más' : ''}; comparte zona y fecha.',
          catalog: false,
        ),
      );
    }
    suggestions.sort((a, b) => b.priority.compareTo(a.priority));
    return suggestions.take(8).toList(growable: false);
  }
}

class _SavingsSuggestion {
  final IconData icon;
  final String title;
  final String detail;
  final bool catalog;
  const _SavingsSuggestion({
    required this.icon,
    required this.title,
    required this.detail,
    required this.catalog,
  });
  int get priority => catalog ? 2 : 1;
}

class _SavingsMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _SavingsMetric(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => Container(
    width: 210,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: kLogisticsCapsuleGradient,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: kLogisticsSilverBorderLight),
    ),
    child: Row(
      children: [
        Icon(icon, color: kLogisticsSilverIcon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: kLogisticsSilverTextPrimary,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: kLogisticsSilverTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SavingsAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final String action;
  final VoidCallback onTap;
  const _SavingsAction({
    required this.icon,
    required this.title,
    required this.detail,
    required this.action,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLogisticsSilverBorderLight),
      ),
      child: Row(
        children: [
          Icon(icon, color: kLogisticsSilverIcon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: kLogisticsSilverTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: kLogisticsSilverTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            action,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: kLogisticsSilverTextPrimary,
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );
}
