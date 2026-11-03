import 'dart:convert';
import 'dart:io';

import 'package:dicsa_operacion/app/menudeo/menudeo_filter_widgets.dart';
import 'package:dicsa_operacion/app/menudeo/menudeo_tickets_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const historicalTicket = <String, dynamic>{
  'id': 'historical-ticket',
  'ticket_number': '59805',
  'ticket_date': '2026-06-05',
  'counterparty_name_snapshot': 'FRIOCIMA',
  'material_label_snapshot': 'CARTON NACIONAL',
  'gross_weight': 22670,
  'tare_weight': 19300,
  'price_at_entry': 1.4,
  'status': 'PAGADO',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  var failHistory = false;
  final options = <Map<String, dynamic>>[
    for (var i = 0; i < 1000; i++) {'ticket_number': '${10000 + i}'},
    {'ticket_number': '59805'},
  ];

  setUpAll(() async {
    await (FontLoader('Roboto')..addFont(
          File(
            'assets/fonts/Roboto-Regular.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://menudeo-ticket-filter-test.invalid',
      anonKey: 'test-only-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        final query = request.url.queryParameters;
        final table = request.url.pathSegments.last;
        var rows = <Map<String, dynamic>>[];
        var count = 0;
        if (table == 'vw_men_tickets_grid') {
          if (query['select'] == 'ticket_number') {
            if (failHistory) {
              return http.Response(
                jsonEncode({'code': '42501', 'message': 'Permission denied'}),
                403,
                headers: {'content-type': 'application/json'},
              );
            }
            final offset = int.parse(query['offset'] ?? '0');
            final limit = int.parse(query['limit'] ?? '1000');
            rows = options.skip(offset).take(limit).toList();
            count = options.length;
          } else if (query.containsKey('ticket_number')) {
            rows = [historicalTicket];
            count = 1;
          } else {
            rows = [
              {
                ...historicalTicket,
                'id': 'recent-ticket',
                'ticket_number': '62000',
                'ticket_date': '2026-10-23',
                'counterparty_name_snapshot': 'PUBLICO GENERAL',
              },
            ];
            count = 1002;
          }
        }
        return http.Response(
          jsonEncode(rows),
          200,
          request: request,
          headers: {
            'content-type': 'application/json',
            'content-range': '*/$count',
          },
        );
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    requests.clear();
    failHistory = false;
  });

  Future<void> openPage(
    WidgetTester tester, {
    MenudeoTicketFlow flow = MenudeoTicketFlow.purchase,
  }) async {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: MenudeoTicketsPage(instantOpen: true, flow: flow)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openFilter(WidgetTester tester) async {
    final header = find.byWidgetPredicate(
      (widget) =>
          widget is MenudeoGridHeaderFilterCell && widget.label == 'Ticket',
    );
    await tester.tap(
      find.descendant(of: header, matching: find.byType(InkWell)),
    );
    await tester.pumpAndSettle();
    // Large history responses are decoded in PostgREST's background isolate.
    for (var i = 0; i < 100 && find.byType(Dialog).evaluate().isEmpty; i++) {
      if (failHistory && find.byType(SnackBar).evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
    }
  }

  Finder searchField() => find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextField),
  );

  for (final flow in MenudeoTicketFlow.values) {
    testWidgets('finds and applies a historical ticket in ${flow.name}', (
      tester,
    ) async {
      await openPage(tester, flow: flow);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == '59805',
        ),
        findsNothing,
      );
      expect(find.text('62000'), findsOneWidget);

      await openFilter(tester);
      expect(
        find.byType(Dialog),
        findsOneWidget,
        reason: requests.map((r) => r.url.toString()).join('\n'),
      );
      expect(
        tester.widget<TextField>(searchField()).focusNode!.hasFocus,
        isTrue,
      );
      await tester.enterText(searchField(), '59805');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsNothing);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == '59805',
        ),
      );
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == '59805',
        ),
        findsOneWidget,
      );
      expect(find.text('FRIOCIMA'), findsOneWidget);
      expect(find.text('05/06/2026'), findsOneWidget);
      expect(find.text('62000'), findsNothing);
      expect(find.text('Total: 1'), findsOneWidget);
      final historyRequests = requests.where(
        (request) => request.url.queryParameters['select'] == 'ticket_number',
      );
      expect(historyRequests, hasLength(2));
      expect(historyRequests.last.url.queryParameters['offset'], '1000');
      for (final request in requests.where(
        (request) => request.url.pathSegments.last == 'vw_men_tickets_grid',
      )) {
        expect(request.url.queryParameters['direction'], 'eq.${flow.name}');
      }

      // Reopening keeps the selected historical number; Escape cancels.
      await openFilter(tester);
      await tester.enterText(searchField(), '59805');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(find.text('FRIOCIMA'), findsOneWidget);
      expect(find.text('Total: 1'), findsOneWidget);
      await openFilter(tester);
      await tester.tap(find.text('Limpiar selección'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == '59805',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'failed history request can be retried without clearing the grid',
    (tester) async {
      await openPage(tester);
      failHistory = true;
      await openFilter(tester);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('62000'), findsOneWidget);
      expect(
        find.text(
          'No se pudo cargar el historial de tickets. Intenta de nuevo.',
        ),
        findsOneWidget,
      );
      failHistory = false;
      await openFilter(tester);
      await tester.enterText(searchField(), '59805');
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == '59805',
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('62000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
