import 'human_resources_employee_status.dart';

/// Extracts a date from the CURP structure, without claiming RENAPO validation.
/// Position 17 distinguishes births before 2000 (digit) and from 2000 (letter).
DateTime? hrBirthDateFromCurp(Object? value, {DateTime? today}) {
  final curp = (value ?? '').toString().trim().toUpperCase();
  if (!RegExp(
    r'^[A-ZÑ]{4}\d{6}[HM][A-Z]{2}[A-ZÑ]{3}[A-Z0-9]\d$',
  ).hasMatch(curp)) {
    return null;
  }
  final century = int.tryParse(curp[16]) == null ? 2000 : 1900;
  final year = century + int.parse(curp.substring(4, 6));
  final month = int.parse(curp.substring(6, 8));
  final day = int.parse(curp.substring(8, 10));
  final birthDate = DateTime(year, month, day);
  final current = today ?? DateTime.now();
  if (birthDate.year != year ||
      birthDate.month != month ||
      birthDate.day != day ||
      birthDate.isAfter(DateTime(current.year, current.month, current.day))) {
    return null;
  }
  return birthDate;
}

class HrEmployeeBirthday {
  final String employeeId;
  final String name;
  final String company;
  final int day;

  const HrEmployeeBirthday({
    required this.employeeId,
    required this.name,
    required this.company,
    required this.day,
  });

  String get initials => name
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word[0])
      .join()
      .toUpperCase();
}

class HrBirthdayMonth {
  final DateTime today;
  final List<HrEmployeeBirthday> employees;
  final int missingBirthDateCount;

  const HrBirthdayMonth({
    required this.today,
    required this.employees,
    required this.missingBirthDateCount,
  });

  static const _months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  String get monthName => _months[today.month - 1];
  String get monthLabel => '$monthName · ${today.year}';
  String get monthAbbreviation => monthName.substring(0, 3).toUpperCase();

  factory HrBirthdayMonth.fromProfiles(
    List<Map<String, dynamic>> profiles, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final employees = <HrEmployeeBirthday>[];
    final seen = <String>{};
    var missing = 0;
    for (final row in profiles) {
      if (!isHrEmployeeOperationalStatus(row['employment_status'])) continue;
      final id = (row['id'] ?? '').toString().trim();
      if (id.isEmpty || !seen.add(id)) continue;
      final birthDate = hrBirthDateFromCurp(row['curp'], today: today);
      if (birthDate == null) {
        missing++;
        continue;
      }
      if (birthDate.month != today.month) continue;
      final name = (row['nombre'] ?? '').toString().trim();
      final company = (row['empresa'] ?? '').toString().trim();
      employees.add(
        HrEmployeeBirthday(
          employeeId: id,
          name: name.isEmpty ? 'ID #$id' : name,
          company: company.isEmpty ? 'Sin empresa' : company,
          day: birthDate.day,
        ),
      );
    }
    employees.sort((a, b) {
      final byDay = a.day.compareTo(b.day);
      if (byDay != 0) return byDay;
      final byName = a.name.toUpperCase().compareTo(b.name.toUpperCase());
      return byName != 0 ? byName : a.employeeId.compareTo(b.employeeId);
    });
    return HrBirthdayMonth(
      today: today,
      employees: List.unmodifiable(employees),
      missingBirthDateCount: missing,
    );
  }
}
