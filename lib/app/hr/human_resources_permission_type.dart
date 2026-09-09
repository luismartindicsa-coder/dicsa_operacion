/// Values persisted by hr_employee_permission_events_type_check.
enum HrPermissionType {
  permisoConGoce('Permiso con goce', 'permiso_con_goce'),
  permisoSinGoce('Permiso sin goce', 'permiso_sin_goce'),
  incapacidad('Incapacidad', 'incapacidad'),
  ajusteRh('Ajuste RH', 'ajuste_rh');

  final String label;
  final String dbValue;

  const HrPermissionType(this.label, this.dbValue);

  static HrPermissionType fromDb(Object? raw) {
    final key = (raw ?? '').toString();
    return values.firstWhere(
      (item) => item.dbValue == key || item.name == key,
      orElse: () => permisoConGoce,
    );
  }
}
