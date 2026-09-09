/// NGTeco baselines from older versions remain available in the database for
/// audit, but only RH captures/projections are operational attendance.
bool isHrOperationalAttendanceRow(Map<String, dynamic> row) =>
    row['source_mode'] != 'importado';
