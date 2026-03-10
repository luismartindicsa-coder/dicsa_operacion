import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/services_shell.dart';
import '../shared/app_error_reporter.dart';

class AuthResolvedProfile {
  final String email;
  final String role;
  final bool isActive;

  const AuthResolvedProfile({
    required this.email,
    required this.role,
    required this.isActive,
  });
}

class AuthAccess {
  static final SupabaseClient _supa = Supabase.instance.client;

  static String _normalizeRoleValue(String? raw) {
    final value = (raw ?? '').toLowerCase().trim();
    return value
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll(RegExp(r'[\s-]+'), '_');
  }

  static bool _isDirectionRoleValue(String role) {
    return role == 'direccion' ||
        role == 'direction' ||
        role == 'auxiliar_direccion' ||
        role == 'direccion_general' ||
        role.startsWith('direccion_') ||
        role.endsWith('_direccion') ||
        role.contains('direction');
  }

  static bool _roleIn(AuthResolvedProfile? profile, Set<String> roles) {
    if (profile == null || !profile.isActive) return false;
    return roles.contains(profile.role);
  }

  static bool hasFullOperationsAccess(AuthResolvedProfile? profile) {
    if (_isDirectionRoleValue(profile?.role ?? '')) return true;
    return _roleIn(profile, {
      'ops_manager',
      'admin',
      'operacion',
      'operations',
    });
  }

  static bool hasLogisticsAccess(AuthResolvedProfile? profile) {
    return _roleIn(profile, {'services', 'logistics', 'logistica'});
  }

  static bool isDirectionRole(AuthResolvedProfile? profile) {
    return _isDirectionRoleValue(profile?.role ?? '');
  }

  static Future<AuthResolvedProfile?> resolveCurrentProfile() async {
    final user = _supa.auth.currentUser;
    if (user == null) return null;

    final email = (user.email ?? '').toLowerCase().trim();
    try {
      final row = await _supa
          .from('profiles')
          .select('role, is_active')
          .eq('user_id', user.id)
          .maybeSingle();
      final normalizedRole = _normalizeRoleValue((row?['role'] as String?));
      return AuthResolvedProfile(
        email: email,
        role: normalizedRole.isEmpty ? 'viewer' : normalizedRole,
        isActive: (row?['is_active'] as bool?) ?? true,
      );
    } catch (e, st) {
      AppErrorReporter.report(
        e,
        st,
        fallbackMessage: 'No se pudo cargar el perfil actual.',
      );
      return AuthResolvedProfile(email: email, role: 'viewer', isActive: true);
    }
  }

  static bool canAccessDashboard(AuthResolvedProfile? profile) {
    return hasFullOperationsAccess(profile);
  }

  static bool canAccessGeneralDashboard(AuthResolvedProfile? profile) {
    return isDirectionRole(profile);
  }

  static bool canOpenCatalogs(AuthResolvedProfile? profile) {
    return canAccessDashboard(profile) || canAccessGeneralDashboard(profile);
  }

  static bool canAccessOperationalModule(
    AuthResolvedProfile? profile,
    ServicesOverlayNavModule module,
  ) {
    if (profile == null || !profile.isActive) return false;
    if (hasFullOperationsAccess(profile)) return true;

    if (hasLogisticsAccess(profile)) {
      return module == ServicesOverlayNavModule.entradasSalidas ||
          module == ServicesOverlayNavModule.servicios ||
          module == ServicesOverlayNavModule.almacen ||
          module == ServicesOverlayNavModule.pesadas;
    }

    if (profile.role == 'maintenance') {
      return module == ServicesOverlayNavModule.mantenimiento;
    }

    return false;
  }

  static String routeKeyForProfile(AuthResolvedProfile? profile) {
    if (profile == null || !profile.isActive) return 'blocked';
    if (_isDirectionRoleValue(profile.role)) return 'dashboard_general';

    switch (profile.role) {
      case 'services':
      case 'logistics':
      case 'logistica':
        return 'services';
      case 'maintenance':
        return 'maintenance';
      case 'ops_manager':
      case 'operacion':
      case 'operations':
      case 'admin':
        return 'dashboard';
      default:
        return 'dashboard';
    }
  }
}

class AuthSessionActions {
  static Future<void>? _pendingSignOut;

  static Future<void> signOut() {
    final existing = _pendingSignOut;
    if (existing != null) return existing;

    final future = Supabase.instance.client.auth.signOut();
    _pendingSignOut = future.whenComplete(() {
      _pendingSignOut = null;
    });
    return _pendingSignOut!;
  }
}
