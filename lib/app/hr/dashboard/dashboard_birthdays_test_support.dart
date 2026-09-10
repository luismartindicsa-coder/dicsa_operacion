part of '../human_resources_dashboard_page.dart';

@visibleForTesting
Widget hrDashboardBirthdayCardForTesting({
  required List<Map<String, dynamic>> profiles,
  required DateTime today,
  String selectedPeriodLabel = '',
}) {
  final data = _HrDashboardData.fromRows(
    selectedPeriodLabel: selectedPeriodLabel,
    profiles: profiles,
    importLots: [],
    attendanceRecords: [],
    vacationEvents: [],
    permissionEvents: [],
    prenominaDrafts: [],
    periodClosures: [],
    now: today,
  );
  return _HrDashboardBirthdayCard(data: data.birthdays);
}
