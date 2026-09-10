part of '../human_resources_dashboard_page.dart';

@visibleForTesting
Map<String, dynamic> hrDashboardVacationsForTesting({
  required List<Map<String, dynamic>> profiles,
  required List<Map<String, dynamic>> events,
  required DateTime today,
}) {
  final data = _HrDashboardData.fromRows(
    selectedPeriodLabel: '',
    profiles: profiles,
    importLots: [],
    attendanceRecords: [],
    vacationEvents: events,
    permissionEvents: [],
    prenominaDrafts: [],
    periodClosures: [],
    now: today,
  );
  return {
    'active': data.activeVacationEmployees,
    'upcoming': data.upcomingVacations.length,
    'active_trend': data.activeVacationTrend,
    'upcoming_trend': data.upcomingVacationTrend,
  };
}

@visibleForTesting
Widget hrDashboardVacationChartForTesting(List<double> values) => SizedBox(
  width: 72,
  height: 54,
  child: _HrDashboardMiniBars(values: values, preserveTimeline: true),
);
