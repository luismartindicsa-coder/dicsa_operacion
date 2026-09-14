import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/auth/auth_access.dart';
import 'package:dicsa_operacion/app/services/services_shell.dart';

void main() {
  const documental = AuthResolvedProfile(
    email: 'gestion@dicsamx.com',
    role: 'gestion_documental',
    isActive: true,
  );

  test(
    'documental profile starts in its area and has no other area access',
    () {
      expect(
        AuthAccess.routeKeyForProfile(documental),
        'gestion_documental_dashboard',
      );
      expect(AuthAccess.canAccessGeneralDashboard(documental), isFalse);
      expect(AuthAccess.canAccessDashboard(documental), isFalse);
      expect(AuthAccess.canAccessFinanzasArea(documental), isFalse);
      expect(AuthAccess.canAccessComprasArea(documental), isFalse);
      expect(AuthAccess.hasHumanResourcesAccess(documental), isFalse);
      expect(AuthAccess.hasManagementAccess(documental), isFalse);
      expect(AuthAccess.hasMenudeoAccess(documental), isFalse);
      expect(AuthAccess.hasMayoreoAccess(documental), isFalse);
      expect(AuthAccess.hasDesarrolloComercialAccess(documental), isFalse);
      expect(AuthAccess.hasLogisticsAccess(documental), isFalse);
      for (final module in ServicesOverlayNavModule.values) {
        expect(
          AuthAccess.canAccessOperationalModule(documental, module),
          isFalse,
        );
      }
    },
  );

  test('documental routing requires an active role, not just an email', () {
    expect(
      AuthAccess.routeKeyForProfile(
        const AuthResolvedProfile(
          email: 'gestion@dicsamx.com',
          role: 'gestion_documental',
          isActive: false,
        ),
      ),
      'blocked',
    );
    expect(
      AuthAccess.routeKeyForProfile(
        const AuthResolvedProfile(
          email: 'gestion@dicsamx.com',
          role: 'viewer',
          isActive: true,
        ),
      ),
      isNot('gestion_documental_dashboard'),
    );
    expect(AuthAccess.routeKeyForProfile(null), 'blocked');
  });

  test(
    'existing direction, admin and logistics destinations are preserved',
    () {
      for (final entry in {
        'direccion': 'dashboard_general',
        'admin': 'dashboard',
        'ops_manager': 'dashboard',
        'services': 'logistics_dashboard',
        'desarrollo_comercial': 'commercial_dashboard',
      }.entries) {
        expect(
          AuthAccess.routeKeyForProfile(
            AuthResolvedProfile(
              email: 'existing@test.invalid',
              role: entry.key,
              isActive: true,
            ),
          ),
          entry.value,
        );
      }
    },
  );
}
