import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_access.dart';
import 'auth_navigation.dart';
import 'login_page.dart';
import 'role_router.dart';
import '../shared/app_error_reporter.dart';
import '../shared/session_expiry_service.dart';
import '../update/app_update_prompt.dart';
import '../update/app_update_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _overlayTotalMs = 880;
  static const _preSwapSignInMs = 180;
  static const _preSwapSignOutMs = 60;
  static const _postSwapDissolveMs = 520;

  late final StreamSubscription<AuthState> _authSub;
  late final AnimationController _switchFx;
  bool _expiring = false;
  bool _hasSession = false;
  bool _transitionToSession = false;
  bool _transitioning = false;
  bool? _queuedSessionState;
  bool _checkedAppUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hasSession = Supabase.instance.client.auth.currentSession != null;
    _switchFx = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _overlayTotalMs),
    );

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) async {
      if (state.event == AuthChangeEvent.signedIn) {
        await SessionExpiryService.instance.markSessionStarted();
        await _scheduleSessionExpiry();
      }
      if (state.event == AuthChangeEvent.signedOut) {
        await SessionExpiryService.instance.clearSessionStart();
        _expiring = false;
      }

      final nextHasSession =
          Supabase.instance.client.auth.currentSession != null;
      if (nextHasSession != _hasSession && mounted) {
        _animateAuthSwap(nextHasSession);
      }
    });

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      unawaited(_handleSessionResumed());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForAppUpdate());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleSessionResumed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub.cancel();
    _switchFx.dispose();
    super.dispose();
  }

  Future<void> _handleSessionResumed() async {
    final hasSession = Supabase.instance.client.auth.currentSession != null;
    if (!hasSession) {
      await SessionExpiryService.instance.clearSessionStart();
      return;
    }

    final expired = await SessionExpiryService.instance.isExpired();
    if (expired) {
      await _expireSession();
      return;
    }

    await _scheduleSessionExpiry();
  }

  Future<void> _scheduleSessionExpiry() async {
    await SessionExpiryService.instance.schedule(onExpired: _expireSession);
  }

  Future<void> _expireSession() async {
    if (_expiring) return;
    _expiring = true;
    final shouldSwapToLogin =
        mounted &&
        _hasSession &&
        !_transitioning &&
        _queuedSessionState == null;

    if (shouldSwapToLogin) {
      setState(() => _hasSession = false);
    }

    try {
      await AuthSessionActions.signOut();
      await SessionExpiryService.instance.clearSessionStart();
      await routeToLogin(animated: false);
      appScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Tu sesión ha expirado')),
      );
    } finally {
      _expiring = false;
    }
  }

  Future<void> _animateAuthSwap(bool nextHasSession) async {
    if (_transitioning) {
      _queuedSessionState = nextHasSession;
      return;
    }

    _transitioning = true;
    _queuedSessionState = null;
    _transitionToSession = nextHasSession;
    _switchFx.forward(from: 0);

    final preSwapDelay = nextHasSession ? _preSwapSignInMs : _preSwapSignOutMs;
    await Future<void>.delayed(Duration(milliseconds: preSwapDelay));
    if (!mounted) return;

    setState(() => _hasSession = nextHasSession);

    await Future<void>.delayed(
      const Duration(milliseconds: _postSwapDissolveMs),
    );
    _transitioning = false;

    final queued = _queuedSessionState;
    if (queued != null && queued != _hasSession && mounted) {
      _queuedSessionState = null;
      _animateAuthSwap(queued);
    }
  }

  Future<void> _checkForAppUpdate() async {
    if (_checkedAppUpdate || !mounted) {
      return;
    }
    _checkedAppUpdate = true;

    try {
      final update = await AppUpdateService.checkForUpdate();
      if (!mounted || update == null) {
        return;
      }

      await showAppUpdatePrompt(context, update);
    } catch (_) {
      // Ignora errores de red o configuracion para no bloquear el acceso.
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _hasSession
        ? const RoleRouter(key: ValueKey('role_router'))
        : const LoginPage(key: ValueKey('login'));
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 980),
          reverseDuration: const Duration(milliseconds: 760),
          switchInCurve: const Interval(0.38, 1.0, curve: Curves.easeOutCubic),
          switchOutCurve: const Interval(0.0, 0.82, curve: Curves.easeOutCubic),
          transitionBuilder: (child, animation) {
            final scale = Tween<double>(begin: 0.998, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            Widget transitioned = FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: scale, child: child),
            );

            final isLogin = child.key == const ValueKey('login');
            if (_transitionToSession && isLogin) {
              transitioned = AnimatedBuilder(
                animation: animation,
                child: transitioned,
                builder: (_, loginChild) {
                  final k = (1 - animation.value).clamp(0.0, 1.0);
                  final blur = Curves.easeOutCubic.transform(k);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      loginChild!,
                      Align(
                        alignment: Alignment.center,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 20 * blur,
                              sigmaY: 20 * blur,
                            ),
                            child: Container(
                              width: 540,
                              height: 560,
                              color: Colors.white.withValues(
                                alpha: 0.08 * blur,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            }

            return transitioned;
          },
          child: target,
        ),
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _switchFx,
            builder: (_, _) {
              final t = _switchFx.value;
              if (t == 0) return const SizedBox.shrink();

              final grow = Curves.easeInOutQuart.transform(t);
              final pulse = t < 0.5
                  ? Curves.easeInOutCubic.transform(t / 0.5)
                  : Curves.easeInOutCubic.transform((1 - t) / 0.5);

              return Opacity(
                opacity: pulse * 0.08,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.white.withValues(alpha: 0.008)),
                    Positioned(
                      left: -260 * grow,
                      top: -160 * grow,
                      child: _transitionBubble(
                        size: 760 * (0.90 + 0.22 * grow),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFFFFF), Color(0xFF7ED0FF)],
                        ),
                      ),
                    ),
                    Positioned(
                      right: -220 * grow,
                      bottom: -170 * grow,
                      child: _transitionBubble(
                        size: 700 * (0.92 + 0.24 * grow),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CFFB2), Color(0xFF00A3FF)],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: 5 * pulse,
                          sigmaY: 5 * pulse,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _transitionBubble({required double size, required Gradient gradient}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
    );
  }
}
