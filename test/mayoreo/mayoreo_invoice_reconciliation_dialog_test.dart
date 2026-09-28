import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/mayoreo/mayoreo_invoice_reconciliation.dart';
import 'package:dicsa_operacion/app/mayoreo/mayoreo_invoice_reconciliation_dialog.dart';
import 'package:dicsa_operacion/app/mayoreo/mayoreo_invoice_reconciliation_store.dart';
import 'package:dicsa_operacion/app/mayoreo/mayoreo_theme.dart';
import 'package:dicsa_operacion/app/shared/ui_contract_core/theme/area_theme_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeRepository implements MayoreoInvoiceRepository {
  final row = MayoreoInvoiceTicket(
    clientKey: 'a',
    clientName: 'CLIENTE A',
    ticketKey: 'B001',
    ticket: 'B001',
    saleDate: DateTime(2026, 9, 28),
    amountCents: 16564000,
    sourceIds: ['sale-1'],
    details: [
      {
        'material': 'CARTÓN',
        'amount_cents': 16564000,
        'remision': 'R001',
        'approved_weight': 30000,
        'approved_price': 5.521333,
      },
    ],
  );
  final calls = <String>[];
  final saved = <MayoreoInvoiceHistory>[];
  Object? saveError;
  Object? usageError;
  bool? usageOverride;
  final usageCalls = <String>[];
  final additionalTickets = <MayoreoManagedInvoiceTicket>[];
  bool get used => usageOverride ?? saved.isNotEmpty;

  @override
  Future<List<MayoreoManagedInvoiceTicket>> loadTickets() async => [
    MayoreoManagedInvoiceTicket(
      ticket: row,
      used: used,
      eligible: true,
      claimIds: used ? ['claim-1'] : [],
      usageOrigin: saved.isNotEmpty ? 'reconciliation' : 'manual',
    ),
    ...additionalTickets,
  ];

  @override
  Future<MayoreoManagedInvoiceTicket> setTicketUsed({
    required String requestId,
    required MayoreoManagedInvoiceTicket ticket,
    required bool used,
  }) async {
    usageCalls.add(requestId);
    if (usageError != null) throw usageError!;
    usageOverride = used;
    return (await loadTickets()).first;
  }

  @override
  Future<List<MayoreoInvoiceClient>> loadClients() async => [
    const MayoreoInvoiceClient('a', 'CLIENTE A'),
    const MayoreoInvoiceClient('b', 'CLIENTE B'),
  ];
  @override
  Future<List<MayoreoInvoiceTicket>> loadCandidates(String clientKey) async =>
      clientKey == 'a' && !used ? [row] : [];
  @override
  Future<List<MayoreoInvoiceTicket>> loadDetails(
    String reconciliationId,
  ) async => [
    MayoreoInvoiceTicket(
      clientKey: row.clientKey,
      clientName: row.clientName,
      ticketKey: row.ticketKey,
      ticket: row.ticket,
      saleDate: row.saleDate,
      amountCents: row.amountCents,
      sourceIds: row.sourceIds,
      details: row.details,
      releasedAt: usageOverride == false ? DateTime(2026, 9, 28) : null,
    ),
  ];
  @override
  Future<List<MayoreoInvoiceHistory>> loadHistory(int offset) async =>
      saved.skip(offset).toList();
  @override
  Future<MayoreoInvoiceHistory> save({
    required String requestId,
    required String clientKey,
    required MayoreoInvoiceMatch match,
    required String reference,
  }) async {
    calls.add(requestId);
    if (saveError != null) throw saveError!;
    final history = MayoreoInvoiceHistory(
      id: requestId,
      clientName: 'CLIENTE A',
      targetCents: match.targetCents,
      totalCents: match.totalCents,
      reference: reference,
      createdAt: DateTime(2026, 9, 28, 13, 30),
    );
    saved.add(history);
    usageOverride = null;
    return history;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final bytes = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    for (final name in ['Roboto', 'Ahem']) {
      await (FontLoader(name)..addFont(Future.value(bytes))).load();
    }
    final config = File('.dart_tool/package_config.json');
    final packages =
        jsonDecode(await config.readAsString())['packages'] as List;
    final flutter = packages.singleWhere((row) => row['name'] == 'flutter');
    final root = config.absolute.uri.resolve('${flutter['rootUri']}/');
    final icons = File.fromUri(
      root.resolve(
        '../../bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    );
    await (FontLoader(
      'MaterialIcons',
    )..addFont(icons.readAsBytes().then(ByteData.sublistView))).load();
  });
  Future<void> open(
    WidgetTester tester,
    FakeRepository repo, {
    double width = 1200,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('capture-root'),
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: mayoreoAreaTokens.primary,
            ),
          ),
          home: Scaffold(
            body: AreaThemeScope(
              tokens: mayoreoAreaTokens,
              child: RepaintBoundary(
                key: const ValueKey('capture'),
                child: MayoreoInvoiceReconciliationDialog(repository: repo),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String variable) async {
    final path = Platform.environment[variable];
    if (path == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(
        ValueKey(
          variable == 'DICSA_OPTIONS_CAPTURE' ? 'capture-root' : 'capture',
        ),
      ),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(path).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> selectClient(
    WidgetTester tester, {
    bool keyboard = false,
  }) async {
    await tester.enterText(
      find.byType(TextField).first,
      keyboard ? 'CLIENTE' : 'CLIENTE A',
    );
    await tester.pumpAndSettle();
    if (keyboard) {
      await capture(tester, 'DICSA_OPTIONS_CAPTURE');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.testTextInput.receiveAction(TextInputAction.done);
    } else {
      await tester.tap(find.text('CLIENTE A').last);
    }
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Importe solicitado'),
      '165643',
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Buscar boletas'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'select, preview shortfall, save, inspect history and exclude used ticket',
    (tester) async {
      final repo = FakeRepository();
      await open(tester, repo);
      expect(
        tester
            .widget<TextField>(find.byType(TextField).first)
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await selectClient(tester, keyboard: true);
      await search(tester);
      expect(find.text(r'$3.00'), findsOneWidget);
      expect(find.textContaining('Boleta B001'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (Platform.environment['DICSA_RECONCILIATION_CAPTURE']
          case final path?) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(path).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Guardar conciliación'));
      await tester.pumpAndSettle();
      expect(repo.saved.single.totalCents, 16564000);
      expect(find.textContaining('quedaron reservadas'), findsOneWidget);
      await tester.tap(find.textContaining('CLIENTE A ·'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Boleta B001'), findsOneWidget);
      await capture(tester, 'DICSA_HISTORY_CAPTURE');
      await tester.tap(find.text('Nueva conciliación'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'CLIENTE A',
      );
      await search(tester);
      expect(find.textContaining('No hay boletas disponibles'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byWidgetPredicate((widget) => widget is FilledButton),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('input edits invalidate preview; narrow layout remains usable', (
    tester,
  ) async {
    await open(tester, FakeRepository(), width: 480);
    await selectClient(tester);
    await search(tester);
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.widgetWithText(TextField, 'Importe solicitado'),
      '5',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate((widget) => widget is FilledButton),
          )
          .onPressed,
      isNull,
    );
    await tester.runAsync(() async {
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.textContaining('No hay boletas disponibles'), findsOneWidget);
  });

  testWidgets(
    'network retry keeps request ID and conflicts require another search',
    (tester) async {
      final repo = FakeRepository()..saveError = Exception('network');
      await open(tester, repo);
      await selectClient(tester);
      await search(tester);
      await tester.tap(find.text('Guardar conciliación'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar guardado'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Importe solicitado'),
            )
            .enabled,
        isFalse,
      );
      repo.saveError = const PostgrestException(
        message: 'Boleta ya utilizada',
        code: 'PT409',
      );
      await tester.tap(find.text('Reintentar guardado'));
      await tester.pumpAndSettle();
      expect(repo.calls[0], repo.calls[1]);
      expect(find.text('Boleta ya utilizada'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byWidgetPredicate((widget) => widget is FilledButton),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'ticket tab filters clients and edits availability used by search',
    (tester) async {
      final repo = FakeRepository();
      repo.additionalTickets.add(
        MayoreoManagedInvoiceTicket(
          ticket: MayoreoInvoiceTicket(
            clientKey: 'b',
            clientName: 'CLIENTE B',
            ticketKey: 'B002',
            ticket: 'B002',
            saleDate: DateTime(2026, 9, 27),
            amountCents: 20000,
            sourceIds: ['sale-2'],
          ),
          used: true,
          eligible: true,
          claimIds: ['claim-2'],
          usageOrigin: 'manual',
        ),
      );
      await open(tester, repo);
      await selectClient(tester);
      await search(tester);
      await tester.tap(find.text('Boletas'));
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsNWidgets(2));
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Filtrar por cliente'),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Filtrar por cliente'),
        'CLIENTE A',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CLIENTE A').last);
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsOneWidget);
      expect(find.textContaining('Boleta B002'), findsNothing);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(repo.used, isTrue);
      expect(find.textContaining('Marcada como usada'), findsOneWidget);
      if (Platform.environment['DICSA_TICKETS_CAPTURE'] case final path?) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(path).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Sin usar'));
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsNothing);
      await tester.tap(find.text('Usadas'));
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsOneWidget);
      await tester.tap(find.text('Nueva conciliación'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byWidgetPredicate((w) => w is FilledButton),
            )
            .onPressed,
        isNull,
      );
      await search(tester);
      expect(find.textContaining('No hay boletas disponibles'), findsOneWidget);
      await tester.tap(find.text('Boletas'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(repo.used, isFalse);
      await tester.tap(find.text('Nueva conciliación'));
      await tester.pumpAndSettle();
      await search(tester);
      expect(find.textContaining('Boleta B001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'releasing an invoice ticket preserves its history with a released label',
    (tester) async {
      final repo = FakeRepository();
      await open(tester, repo);
      await selectClient(tester);
      await search(tester);
      await tester.tap(find.text('Guardar conciliación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boletas'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Usada en conciliación'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('CLIENTE A ·'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Liberada para volver a conciliar'),
        findsOneWidget,
      );
      expect(repo.saved.single.totalCents, 16564000);
    },
  );

  testWidgets(
    'usage retry keeps request and narrow ticket layout has no overflow',
    (tester) async {
      final repo = FakeRepository()..usageError = Exception('network');
      await open(tester, repo, width: 480);
      await tester.tap(find.text('Boletas'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(repo.used, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      repo.usageError = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(repo.usageCalls[0], repo.usageCalls[1]);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(tester.takeException(), isNull);
      await capture(tester, 'DICSA_TICKETS_NARROW_CAPTURE');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
