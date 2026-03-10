import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/shared/app_error_reporter.dart';
import 'app/splash/dicsa_splash_animate.dart';
import 'env.dart'; // si hiciste el archivo env.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppErrorReporter.report(
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };
  ErrorWidget.builder = (details) {
    AppErrorReporter.showMessage(details.exceptionAsString());
    return Material(
      color: const Color(0xFFFBE9E7),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Ocurrio un error en esta pantalla.\n${details.exceptionAsString()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7F1D1D),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppErrorReporter.report(error, stackTrace);
    return true;
  };

  await runZonedGuarded(
    () async {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      );

      runApp(const DicsaApp());
    },
    (error, stackTrace) {
      AppErrorReporter.report(error, stackTrace);
    },
  );
}

class DicsaApp extends StatelessWidget {
  const DicsaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF13D183), // verde del logo
          primary: const Color(0xFF13D183),
        ),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'MX'),
        Locale('es'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'MX'),
      home: const DicsaSplashAnimate(),
    );
  }
}
