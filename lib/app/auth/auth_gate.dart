import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_access.dart';
import 'auth_navigation.dart';
import '../direction/direction_operations_repository.dart';
import '../direction/direction_purchase_orders_page.dart';
import 'login_page.dart';
import 'role_router.dart';
import '../shared/app_error_reporter.dart';
import '../shared/page_routes.dart';
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
  static const _appUpdatePollInterval = Duration(minutes: 15);

  late final StreamSubscription<AuthState> _authSub;
  late final AnimationController _switchFx;
  final DirectionOperationsRepository _directionOperationsRepository =
      DirectionOperationsRepository();
  Timer? _appUpdateTimer;
  Timer? _directionPurchaseOrderTimer;
  RealtimeChannel? _directionPurchaseOrderChannel;
  bool _expiring = false;
  bool _hasSession = false;
  bool _transitionToSession = false;
  bool _transitioning = false;
  bool _watchingDirectionPurchaseOrders = false;
  bool _showingDirectionPurchaseDialog = false;
  bool? _queuedSessionState;
  bool _checkingAppUpdate = false;
  String? _lastPromptedUpdateVersion;
  String? _lastDirectionPurchaseSignature;

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
        unawaited(_refreshDirectionPurchaseOrderAlerts());
      }
      if (state.event == AuthChangeEvent.signedOut) {
        await SessionExpiryService.instance.clearSessionStart();
        _expiring = false;
        _stopDirectionPurchaseOrderAlerts();
      }
      if (state.event == AuthChangeEvent.tokenRefreshed ||
          state.event == AuthChangeEvent.userUpdated) {
        unawaited(_refreshDirectionPurchaseOrderAlerts());
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
      unawaited(_refreshDirectionPurchaseOrderAlerts());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForAppUpdate());
    });
    _appUpdateTimer = Timer.periodic(_appUpdatePollInterval, (_) {
      unawaited(_checkForAppUpdate());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleSessionResumed());
      unawaited(_checkForAppUpdate());
      unawaited(_refreshDirectionPurchaseOrderAlerts());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appUpdateTimer?.cancel();
    _stopDirectionPurchaseOrderAlerts();
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

  Future<void> _refreshDirectionPurchaseOrderAlerts() async {
    final profile = await AuthAccess.resolveCurrentProfile();
    if (!mounted) return;
    if (!AuthAccess.isDirectionRole(profile)) {
      _stopDirectionPurchaseOrderAlerts();
      return;
    }
    _startDirectionPurchaseOrderAlerts();
  }

  void _startDirectionPurchaseOrderAlerts() {
    if (_watchingDirectionPurchaseOrders) return;
    _watchingDirectionPurchaseOrders = true;
    unawaited(_checkDirectionPurchaseOrders());
    _directionPurchaseOrderTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_checkDirectionPurchaseOrders()),
    );
    _directionPurchaseOrderChannel = Supabase.instance.client
        .channel('global-direction-purchase-orders-alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_purchase_orders',
          callback: (_) => unawaited(_checkDirectionPurchaseOrders()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_purchase_order_lines',
          callback: (_) => unawaited(_checkDirectionPurchaseOrders()),
        )
        .subscribe();
  }

  void _stopDirectionPurchaseOrderAlerts() {
    _watchingDirectionPurchaseOrders = false;
    _directionPurchaseOrderTimer?.cancel();
    _directionPurchaseOrderTimer = null;
    final channel = _directionPurchaseOrderChannel;
    _directionPurchaseOrderChannel = null;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    _lastDirectionPurchaseSignature = null;
  }

  Future<void> _checkDirectionPurchaseOrders() async {
    if (!_watchingDirectionPurchaseOrders) return;
    try {
      final summary = await _directionOperationsRepository
          .loadPurchaseOrdersSummary();
      if (!mounted || !_watchingDirectionPurchaseOrders) return;
      _handleDirectionPurchaseOrdersSummary(summary);
    } catch (_) {
      // Ignora errores temporales para no bloquear la sesión.
    }
  }

  void _handleDirectionPurchaseOrdersSummary(
    DirectionPurchaseOrdersSummary summary,
  ) {
    if (summary.pendingCount <= 0) return;
    final signature = summary.pendingItems
        .map(
          (item) =>
              '${item.id}:${item.updatedAt?.toIso8601String() ?? item.createdAt?.toIso8601String() ?? ''}',
        )
        .join('|');
    if (signature.isEmpty ||
        signature == _lastDirectionPurchaseSignature ||
        _showingDirectionPurchaseDialog) {
      return;
    }
    _lastDirectionPurchaseSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _showingDirectionPurchaseDialog) return;
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;
      _showingDirectionPurchaseDialog = true;
      await SystemSound.play(SystemSoundType.alert);
      if (!mounted || !navigator.mounted) {
        _showingDirectionPurchaseDialog = false;
        return;
      }
      await showDialog<void>(
        context: navigator.context,
        barrierDismissible: true,
        builder: (context) {
          final accent = summary.criticalCount > 0
              ? const Color(0xFFFF6B7A)
              : const Color(0xFFFFB45E);
          final top = summary.pendingItems.isNotEmpty
              ? summary.pendingItems.first
              : null;
          return AlertDialog(
            backgroundColor: const Color(0xFF091731),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: BorderSide(color: accent.withValues(alpha: 0.42)),
            ),
            titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
            contentPadding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
            actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            title: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.54)),
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: accent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Compras OT requieren Dirección',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.criticalCount > 0
                        ? 'Hay ${summary.pendingCount} órdenes pendientes y ${summary.criticalCount} ya están en nivel crítico.'
                        : 'Hay ${summary.pendingCount} órdenes de compra esperando validación ejecutiva.',
                    style: const TextStyle(
                      color: Color(0xFFD0E4FF),
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _DirectionPurchasePopupBadge(
                        label: 'Pendientes',
                        value: '${summary.pendingCount}',
                      ),
                      _DirectionPurchasePopupBadge(
                        label: 'Críticas',
                        value: '${summary.criticalCount}',
                      ),
                      _DirectionPurchasePopupBadge(
                        label: 'Monto',
                        value: _formatDirectionPopupMoney(
                          summary.pendingAmount,
                        ),
                      ),
                    ],
                  ),
                  if (top != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Orden más urgente: ${top.folio}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${top.targetLabel} · ${top.vendorName.isEmpty ? 'Sin proveedor' : top.vendorName}',
                            style: const TextStyle(
                              color: Color(0xFFD0E4FF),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${top.ageHours.round()} h · ${_formatDirectionPopupMoney(top.total)}',
                            style: const TextStyle(
                              color: Color(0xFFD0E4FF),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Después'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  navigator.push(
                    appPageRoute(
                      page: const DirectionPurchaseOrdersPage(
                        instantOpen: true,
                      ),
                      duration: const Duration(milliseconds: 300),
                      reverseDuration: const Duration(milliseconds: 220),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Abrir Compras OT'),
              ),
            ],
          );
        },
      );
      _showingDirectionPurchaseDialog = false;
    });
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
    if (_checkingAppUpdate || !mounted) {
      return;
    }
    _checkingAppUpdate = true;

    try {
      final update = await AppUpdateService.checkForUpdate();
      if (!mounted || update == null) {
        return;
      }

      if (_lastPromptedUpdateVersion == update.latestVersion) {
        return;
      }

      _lastPromptedUpdateVersion = update.latestVersion;
      await showAppUpdatePrompt(context, update);
    } catch (_) {
      // Ignora errores de red o configuracion para no bloquear el acceso.
    } finally {
      _checkingAppUpdate = false;
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

String _formatDirectionPopupMoney(num value) {
  final abs = value.abs();
  final text = abs.toStringAsFixed(2);
  final parts = text.split('.');
  final whole = parts.first;
  final decimal = parts.last;
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final position = whole.length - i;
    buffer.write(whole[i]);
    if (position > 1 && position % 3 == 1) {
      buffer.write(',');
    }
  }
  return '${value < 0 ? '-' : ''}\$${buffer.toString()}.$decimal';
}

class _DirectionPurchasePopupBadge extends StatelessWidget {
  final String label;
  final String value;

  const _DirectionPurchasePopupBadge({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
