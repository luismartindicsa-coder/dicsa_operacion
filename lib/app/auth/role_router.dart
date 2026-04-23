import 'package:flutter/material.dart';

import 'auth_access.dart';
import '../maintenance/maintenance_page.dart';
import '../dashboard/general_dashboard_page.dart';
import '../mayoreo/mayoreo_dashboard_preview_page.dart';
import '../menudeo/menudeo_dashboard_page.dart';
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
    _target = _resolveTarget();
  }

  Future<Widget> _resolveTarget() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (profile == null) return const _NoSession();
    if (!profile.isActive) return _BlockedUser(email: profile.email);

    switch (AuthAccess.routeKeyForProfile(profile)) {
      case 'menudeo_dashboard':
        return const MenudeoDashboardPage();
      case 'mayoreo_dashboard':
        return const MayoreoDashboardPreviewPage();
      case 'services':
        return const ServicesPage();
      case 'maintenance':
        return const MaintenancePage();
      case 'dashboard_general':
        return const GeneralDashboardPage();
      case 'dashboard':
      default:
        return const DashboardPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _target,
      builder: (_, snap) {
        final nextChild = switch (snap.connectionState) {
          ConnectionState.done when snap.hasError => Scaffold(
            key: const ValueKey('role-error'),
            body: Center(child: Text('Error RoleRouter:\n${snap.error}')),
          ),
          ConnectionState.done => snap.data ?? const _NoSession(),
          _ => const _RoleRouterLoading(),
        };

        if (snap.connectionState != ConnectionState.done) {
          _immediateTarget = null;
        } else if (snap.hasData) {
          _immediateTarget ??= snap.data;
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 520),
          reverseDuration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) {
            final fade = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.012),
              end: Offset.zero,
            ).animate(fade);
            return FadeTransition(
              opacity: fade,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<String>(switch (nextChild) {
              _RoleRouterLoading _ => 'loading',
              _BlockedUser _ => 'blocked',
              _NoSession _ => 'no-session',
              _ => nextChild.runtimeType.toString(),
            }),
            child: nextChild,
          ),
        );
      },
    );
  }
}

class _RoleRouterLoading extends StatelessWidget {
  const _RoleRouterLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF7FCFF),
                  Color(0xFFEAF6FF),
                  Color(0xFFE7FFF5),
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              width: 170,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.70),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Abriendo dashboard...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF355454),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
