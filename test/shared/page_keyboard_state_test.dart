// These tests exercise the two platform keyboard messages separately because
// macOS can deliver a page transition between key data and its raw message.
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/direction/direction_cash_entries_exits_page.dart';
import 'package:dicsa_operacion/app/menudeo/menudeo_deposits_expenses_page.dart';
import 'package:dicsa_operacion/app/menudeo/menudeo_tickets_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Use Flutter's real font: Ahem makes the existing compact pagers overflow.
    final packageConfig = File('.dart_tool/package_config.json');
    final packages =
        jsonDecode(await packageConfig.readAsString())['packages']
            as List<dynamic>;
    final flutterPackage = packages.singleWhere((p) => p['name'] == 'flutter');
    final flutterRoot = packageConfig.absolute.uri.resolve(
      '${flutterPackage['rootUri']}/',
    );
    final font = File.fromUri(
      flutterRoot.resolve(
        '../../bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      ),
    );
    await (FontLoader(
      'Roboto',
    )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://keyboard-test.invalid',
      anonKey: 'test-only-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient(
        (request) async => http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json', 'content-range': '*/0'},
        ),
      ),
    );
  });

  tearDownAll(() => Supabase.instance.dispose());

  final pages = <String, Widget Function()>{
    'tickets de Menudeo': () => const MenudeoTicketsPage(instantOpen: true),
    'depósitos y gastos': () =>
        const MenudeoDepositsExpensesPage(instantOpen: true),
    'entradas y salidas de Dirección': () =>
        const DirectionCashEntriesExitsPage(instantOpen: true),
  };

  for (final entry in pages.entries) {
    testWidgets('abrir ${entry.key} conserva el Escape pendiente', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final keyboard = HardwareKeyboard.instance;
      final manager = ServicesBinding.instance.keyEventManager;
      final events = <KeyEvent>[];
      bool record(KeyEvent event) {
        events.add(event);
        return false;
      }

      keyboard.addHandler(record);
      addTearDown(() => keyboard.removeHandler(record));

      // The engine has already recorded Escape; the framework has queued it,
      // but will apply it when the matching raw message arrives. Querying and
      // copying the engine state in initState would pre-press Escape and make
      // this legitimate pending KeyDown fail the framework assertion.
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.keyboard,
        (_) async => <int, int>{
          PhysicalKeyboardKey.escape.usbHidUsage:
              LogicalKeyboardKey.escape.keyId,
        },
      );
      addTearDown(() {
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.keyboard,
          null,
        );
      });

      manager.handleKeyData(
        ui.KeyData(
          timeStamp: Duration.zero,
          type: ui.KeyEventType.down,
          character: null,
          synthesized: false,
          physical: PhysicalKeyboardKey.escape.usbHidUsage,
          logical: LogicalKeyboardKey.escape.keyId,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: entry.value(),
        ),
      );
      await tester.pump();
      await manager.handleRawKeyMessage(
        KeyEventSimulator.getKeyData(
          LogicalKeyboardKey.escape,
          platform: 'macos',
        ),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape, platform: 'macos');
      // A second full tap must also work, without replaying the first down.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape, platform: 'macos');

      expect(events.map((event) => event.runtimeType), <Type>[
        KeyDownEvent,
        KeyUpEvent,
        KeyDownEvent,
        KeyUpEvent,
      ]);
      expect(keyboard.physicalKeysPressed, isEmpty);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
