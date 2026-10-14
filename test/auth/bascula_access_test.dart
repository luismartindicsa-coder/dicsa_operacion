import 'package:dicsa_operacion/app/auth/auth_access.dart';
import 'package:dicsa_operacion/app/services/services_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const allowed = {
    ServicesOverlayNavModule.entradasSalidas,
    ServicesOverlayNavModule.pesadas,
    ServicesOverlayNavModule.almacen,
  };

  for (final profile in [
    const AuthResolvedProfile(
      email: 'bascula@dicsamx.com',
      role: 'bascula',
      isActive: true,
    ),
    const AuthResolvedProfile(
      email: 'bascula@dicsamx.com',
      role: 'viewer',
      isActive: true,
    ),
    const AuthResolvedProfile(
      email: ' BASCULA@DICSAMX.COM ',
      role: 'services',
      isActive: true,
    ),
    const AuthResolvedProfile(
      email: 'bascula@dicsamx.com',
      role: 'admin',
      isActive: true,
    ),
    const AuthResolvedProfile(
      email: 'bascula@dicsamx.com',
      role: 'direccion',
      isActive: true,
    ),
    const AuthResolvedProfile(
      email: 'another-scale@example.test',
      role: 'bascula',
      isActive: true,
    ),
  ]) {
    test(
      'Báscula allows only its three screens: ${profile.email}/${profile.role}',
      () {
        expect(AuthAccess.routeKeyForProfile(profile), 'entradas_salidas');
        expect(AuthAccess.hasBasculaAccess(profile), isTrue);
        expect(AuthAccess.hasFullOperationsAccess(profile), isFalse);
        expect(AuthAccess.hasLogisticsAccess(profile), isFalse);
        expect(AuthAccess.canAccessLogisticsControlDaily(profile), isFalse);
        expect(AuthAccess.canAccessDashboard(profile), isFalse);
        expect(AuthAccess.canAccessGeneralDashboard(profile), isFalse);
        expect(AuthAccess.canOpenCatalogs(profile), isFalse);
        expect(AuthAccess.canAccessFinanzasArea(profile), isFalse);
        expect(AuthAccess.canAccessComprasArea(profile), isFalse);
        expect(AuthAccess.hasMenudeoAccess(profile), isFalse);
        expect(AuthAccess.hasMayoreoAccess(profile), isFalse);
        expect(AuthAccess.hasHumanResourcesAccess(profile), isFalse);
        expect(AuthAccess.hasManagementAccess(profile), isFalse);
        expect(AuthAccess.hasDesarrolloComercialAccess(profile), isFalse);
        for (final module in ServicesOverlayNavModule.values) {
          expect(
            AuthAccess.canAccessOperationalModule(profile, module),
            allowed.contains(module),
            reason: module.name,
          );
        }
      },
    );
  }

  test('inactive and missing sessions cannot open Báscula', () {
    for (final profile in [
      null,
      const AuthResolvedProfile(
        email: 'bascula@dicsamx.com',
        role: 'bascula',
        isActive: false,
      ),
    ]) {
      expect(AuthAccess.hasBasculaAccess(profile), isFalse);
      expect(AuthAccess.routeKeyForProfile(profile), 'blocked');
      for (final module in ServicesOverlayNavModule.values) {
        expect(AuthAccess.canAccessOperationalModule(profile, module), isFalse);
      }
    }
  });

  test('existing operations and logistics access is preserved', () {
    const operations = AuthResolvedProfile(
      email: 'operacion@dicsamx.com',
      role: 'ops_manager',
      isActive: true,
    );
    const logistics = AuthResolvedProfile(
      email: 'logistics@example.test',
      role: 'services',
      isActive: true,
    );
    expect(AuthAccess.routeKeyForProfile(operations), 'dashboard');
    expect(AuthAccess.routeKeyForProfile(logistics), 'logistics_dashboard');
    expect(AuthAccess.hasBasculaAccess(operations), isFalse);
    expect(AuthAccess.hasBasculaAccess(logistics), isFalse);
    for (final module in ServicesOverlayNavModule.values) {
      expect(
        AuthAccess.canAccessOperationalModule(operations, module),
        module != ServicesOverlayNavModule.servicios,
      );
      expect(
        AuthAccess.canAccessOperationalModule(logistics, module),
        {
          ...allowed,
          ServicesOverlayNavModule.servicios,
          ServicesOverlayNavModule.directorioOperacion,
        }.contains(module),
      );
    }
  });
}
