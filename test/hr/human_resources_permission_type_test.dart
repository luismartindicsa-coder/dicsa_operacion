import 'dart:io';

import 'package:dicsa_operacion/app/hr/human_resources_permission_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every permission type matches the database check constraint', () {
    final migration = File(
      'supabase/migrations/20260706193000_create_hr_permissions_foundation.sql',
    ).readAsStringSync();
    final constraint = RegExp(
      r'check \(permission_type in \(([^)]+)\)\)',
    ).firstMatch(migration)!;
    final allowed = RegExp(
      "'([^']+)'",
    ).allMatches(constraint.group(1)!).map((match) => match.group(1)!).toSet();

    expect(
      HrPermissionType.values.map((type) => type.dbValue).toSet(),
      allowed,
    );
    for (final type in HrPermissionType.values) {
      expect(HrPermissionType.fromDb(type.dbValue), type);
    }
  });

  test('unpaid leave and HR adjustments retain their type when loaded', () {
    expect(
      HrPermissionType.fromDb('permiso_sin_goce'),
      HrPermissionType.permisoSinGoce,
    );
    expect(HrPermissionType.fromDb('ajuste_rh'), HrPermissionType.ajusteRh);
  });

  test('legacy enum names remain readable', () {
    for (final type in HrPermissionType.values) {
      expect(HrPermissionType.fromDb(type.name), type);
    }
  });
}
