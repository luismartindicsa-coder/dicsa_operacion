import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/dicsa_logo_mark.dart';
import '../shared/session_expiry_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _rememberKey = 'login_remember_me';
  static const _rememberedUserKey = 'login_remembered_user';

  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _passFocus = FocusNode();
  bool _hide = true;
  bool _remember = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedUser();
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_rememberKey) ?? false;
    final rememberedUser = prefs.getString(_rememberedUserKey) ?? '';

    if (remember && rememberedUser.isNotEmpty) {
      _email.text = rememberedUser;
    }

    if (!mounted) return;
    setState(() => _remember = remember);
  }

  Future<void> _persistRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, _remember);

    if (_remember) {
      await prefs.setString(_rememberedUserKey, _email.text.trim());
    } else {
      await prefs.remove(_rememberedUserKey);
    }
  }

  Future<void> _login() async {
    await _persistRememberedUser();
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
      await SessionExpiryService.instance.markSessionStarted(force: true);
      // ✅ No Navigator aquí. AuthGate detecta sesión y redirecciona.
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado al iniciar sesión: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, cts) {
        final w = cts.maxWidth;
        final h = cts.maxHeight;
        final cardWidth = min(w - 32, 540.0);
        final logoSize = min(w, h) * 0.13;
        const radius = 26.0;
        final inputBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
        );
        final focusBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF48B2FF), width: 1.6),
        );

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0B2545),
                  Color(0xFF0F5A75),
                  Color(0xFF1EA896),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -90,
                  right: -60,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -120,
                  left: -80,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: cardWidth),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(radius),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 30,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(radius),
                                color: Colors.white.withValues(alpha: 0.14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1.1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.16),
                                    blurRadius: 30,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Hero(
                                    tag: 'dicsa_d',
                                    child: DicsaLogoD(
                                      size: logoSize.clamp(84, 132),
                                      progress: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Bienvenido',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Inicia sesión para continuar',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.white.withValues(
                                        alpha: 0.88,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  TextField(
                                    controller: _email,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (_) =>
                                        _passFocus.requestFocus(),
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Usuario',
                                      labelStyle: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.82,
                                        ),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.person_outline_rounded,
                                        color: Colors.white.withValues(
                                          alpha: 0.86,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                      enabledBorder: inputBorder,
                                      border: inputBorder,
                                      focusedBorder: focusBorder,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: _pass,
                                    focusNode: _passFocus,
                                    obscureText: _hide,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) {
                                      if (_loading) return;
                                      _login();
                                    },
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Contraseña',
                                      labelStyle: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.82,
                                        ),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.lock_outline_rounded,
                                        color: Colors.white.withValues(
                                          alpha: 0.86,
                                        ),
                                      ),
                                      suffixIcon: IconButton(
                                        onPressed: () =>
                                            setState(() => _hide = !_hide),
                                        icon: Icon(
                                          _hide
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded,
                                          color: Colors.white.withValues(
                                            alpha: 0.86,
                                          ),
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                      enabledBorder: inputBorder,
                                      border: inputBorder,
                                      focusedBorder: focusBorder,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _remember,
                                        side: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.70,
                                          ),
                                        ),
                                        fillColor:
                                            WidgetStateProperty.resolveWith((
                                              states,
                                            ) {
                                              if (states.contains(
                                                WidgetState.selected,
                                              )) {
                                                return const Color(0xFF1B9CFC);
                                              }
                                              return Colors.white.withValues(
                                                alpha: 0.08,
                                              );
                                            }),
                                        checkColor: Colors.white,
                                        onChanged: (value) {
                                          final next = value ?? false;
                                          setState(() => _remember = next);
                                          _persistRememberedUser();
                                        },
                                      ),
                                      Text(
                                        'Recordarme',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.92,
                                          ),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: _loading
                                            ? null
                                            : () {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Contacta al administrador para restablecer tu contraseña.',
                                                    ),
                                                  ),
                                                );
                                              },
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white
                                              .withValues(alpha: 0.92),
                                        ),
                                        child: const Text('Olvidé contraseña'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(15),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF1A73E8),
                                            Color(0xFF0AA5C8),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF0A5EA8,
                                            ).withValues(alpha: 0.42),
                                            blurRadius: 18,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _loading ? null : _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                          ),
                                        ),
                                        child: _loading
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.6,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                            : const Text(
                                                'Entrar',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  fontSize: 15.5,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
