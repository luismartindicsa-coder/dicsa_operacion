import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../maintenance/maintenance_page.dart';
import '../services/services_page.dart';
import '../dashboard/dashboard_page.dart';

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  Widget? _immediateTarget;
  late final Future<Widget> _target;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final email = (user?.email ?? '').toLowerCase().trim();
    if (email == 'logistica@dicsamx.com') {
      _immediateTarget = const ServicesPage();
    } else if (email == 'operacion@dicsamx.com' ||
        email == 'administracion@dicsamx.com') {
      _immediateTarget = const DashboardPage();
    }
    _target = _resolveTarget();
  }

  Future<Widget> _resolveTarget() async {
    final supa = Supabase.instance.client;
    final user = supa.auth.currentUser;

    if (user == null) {
      // Si por alguna razón no hay sesión, manda a una pantalla simple
      return const _NoSession();
    }

    final email = (user.email ?? '').toLowerCase().trim();

    // ✅ Regla dura por email (tu requerimiento)
    if (email == 'logistica@dicsamx.com') {
      return const ServicesPage();
    }
    if (email == 'operacion@dicsamx.com' ||
        email == 'administracion@dicsamx.com') {
      return const DashboardPage();
    }

    // ✅ Regla por rol en profiles
    final row = await supa
        .from('profiles')
        .select('role, is_active')
        .eq('user_id', user.id)
        .maybeSingle();

    final isActive = (row?['is_active'] as bool?) ?? true;
    final role = ((row?['role'] as String?) ?? 'viewer').toLowerCase().trim();

    if (!isActive) return _BlockedUser(email: email);

    // ✅ Routing por rol
    if (role == 'services') return const ServicesPage();
    if (role == 'maintenance') return const MaintenancePage();
    if (role == 'ops_manager' || role == 'admin') return const DashboardPage();

    // viewer / fleet / fuel (por ahora) -> dashboard
    return const DashboardPage();
  }

  @override
  Widget build(BuildContext context) {
    if (_immediateTarget != null) {
      return _immediateTarget!;
    }

    return FutureBuilder<Widget>(
      future: _target,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(child: Text('Error RoleRouter:\n${snap.error}')),
          );
        }
        return snap.data ?? const _NoSession();
      },
    );
  }
}

class _BlockedUser extends StatelessWidget {
  final String email;
  const _BlockedUser({required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Usuario desactivado: $email')));
  }
}

class _NoSession extends StatelessWidget {
  const _NoSession();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('No hay sesión activa.')));
  }
}
