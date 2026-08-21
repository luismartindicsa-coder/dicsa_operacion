const String kHrEmployeeStatusActive = 'activo';
const String kHrEmployeeStatusTerminated = 'baja';

bool isHrEmployeeOperationalStatus(Object? value) {
  return value?.toString().trim().toLowerCase() != kHrEmployeeStatusTerminated;
}
