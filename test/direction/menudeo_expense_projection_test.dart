import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/direction/projection/menudeo_expense_projection.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_repository.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_view.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_expenses_pdf.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_pdf.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'expected_income_test.dart' as f;
import 'expected_income_view_test.dart' as income_ui;
import 'weekly_projection_view_test.dart' as expense_ui;
import 'expected_income_pdf_test.dart' as pdf;

MenudeoExpenseHistory history({
  List<MenudeoExpenseMovement> extra = const [],
}) => MenudeoExpenseHistory(
  movements: [
    for (var w = 1; w <= 6; w++)
      for (var d = 0; d < 6; d++) ...[
        MenudeoExpenseMovement(
          'p-$w-$d',
          f.incomeWeek.subtract(Duration(days: 7 * w)).add(Duration(days: d)),
          10000,
          purchase: true,
        ),
        MenudeoExpenseMovement(
          'e-$w-$d',
          f.incomeWeek.subtract(Duration(days: 7 * w)).add(Duration(days: d)),
          2000,
          purchase: false,
        ),
      ],
    ...extra,
  ],
);
MenudeoExpenseEstimate estimate({
  DateTime? now,
  MenudeoExpenseSettings settings = const MenudeoExpenseSettings(),
  MenudeoExpenseHistory? source,
}) => MenudeoExpenseEstimate(
  week: f.incomeWeek,
  now: now ?? f.incomeWeek,
  history: source ?? history(),
  settings: settings,
);
WeeklyExpensePlan plan(MenudeoExpenseEstimate e) => WeeklyExpensePlan(
  week: f.incomeWeek,
  generated: true,
  openingCash: 100000,
  openingFiscal: 200000,
  menudeo: e.settings,
  menudeoPayments: e.payments,
  menudeoWarnings: e.warnings,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Roboto', 'Ahem']) {
      await (FontLoader(family)..addFont(
            Future.value(
              ByteData.sublistView(
                await File('assets/fonts/Roboto-Regular.ttf').readAsBytes(),
              ),
            ),
          ))
          .load();
    }
    final iconPath = Platform.environment['DICSA_MENUDEO_ICONS'];
    if (iconPath != null) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(
              ByteData.sublistView(await File(iconPath).readAsBytes()),
            ),
          ))
          .load();
    }
  });
  test(
    'six complete weeks include zero weekdays, exclude future and retain separate concepts',
    () {
      final e = estimate(
        source: history(
          extra: [
            MenudeoExpenseMovement(
              'old',
              f.incomeWeek.subtract(const Duration(days: 43)),
              999999,
              purchase: true,
            ),
            MenudeoExpenseMovement(
              'future',
              f.incomeWeek.add(const Duration(days: 1)),
              999999,
              purchase: true,
            ),
          ],
        ),
      );
      expect(e.weeks, 6);
      expect(e.records, 72);
      expect(e.averagePurchases, [10000, 10000, 10000, 10000, 10000, 10000, 0]);
      expect(e.averageExpenses, [2000, 2000, 2000, 2000, 2000, 2000, 0]);
      expect(e.pending, 72000);
      expect(e.actual, 0);
      expect(e.payments.length, 12);
      expect(e.payments.every((r) => r.paymentType == 'EFECTIVO'), true);
      final flow = WeeklyCashFlow(f.forecast().current, plan(e));
      expect(flow.expenses, 72000);
      expect(flow.expense('FISCAL'), 0);
      expect(flow.closingFor('EFECTIVO'), 7378000);
    },
  );
  test(
    'current week subtracts today actuals and never includes elapsed days or negative estimates',
    () {
      final day = f.incomeWeek.add(const Duration(days: 2));
      final e = estimate(
        now: day,
        source: history(
          extra: [
            MenudeoExpenseMovement(
              'monday',
              f.incomeWeek,
              15000,
              purchase: true,
            ),
            MenudeoExpenseMovement('today', day, 4000, purchase: true),
            MenudeoExpenseMovement('todayexpense', day, 3000, purchase: false),
          ],
        ),
      );
      expect(e.remaining(true), [0, 0, 6000, 10000, 10000, 10000, 0]);
      expect(e.remaining(false), [0, 0, 0, 2000, 2000, 2000, 0]);
      expect(e.actual, 22000);
      expect(e.pending, 42000);
      expect(
        estimate(now: f.incomeWeek.add(const Duration(days: 7))).pending,
        0,
      );
    },
  );
  test(
    'future projections use history before current Monday, never future records',
    () {
      final next = f.incomeWeek.add(const Duration(days: 7));
      final e = MenudeoExpenseEstimate(
        week: next,
        now: f.incomeWeek.add(const Duration(days: 2)),
        history: history(
          extra: [
            MenudeoExpenseMovement(
              'current',
              f.incomeWeek,
              999999,
              purchase: true,
            ),
          ],
        ),
      );
      expect(e.historyEnd, f.incomeWeek);
      expect(e.pending, 72000);
    },
  );
  test(
    'manual budgets preserve cents, exclusion affects totals only, empty history is explicit',
    () {
      final e = estimate(
        settings: const MenudeoExpenseSettings(purchases: 10001, expenses: 0),
      );
      expect(e.sum(e.budget(true)), 10001);
      expect(e.pending, 10001);
      final excluded = estimate(
        settings: const MenudeoExpenseSettings(included: false),
      );
      expect(excluded.pending, 72000);
      expect(plan(excluded).total, 0);
      final empty = estimate(source: const MenudeoExpenseHistory());
      expect(empty.weeks, 0);
      expect(empty.pending, 0);
      expect(empty.warnings.join(), contains('Sin historial'));
      final manual = estimate(
        source: const MenudeoExpenseHistory(),
        settings: const MenudeoExpenseSettings(purchases: 10001, expenses: 0),
      );
      expect(manual.pending, 10001);
      expect(manual.payments.length, 7);
      final limited = estimate(
        source: MenudeoExpenseHistory(
          movements: [
            MenudeoExpenseMovement(
              'single',
              f.incomeWeek.subtract(const Duration(days: 7)),
              10000,
              purchase: true,
            ),
          ],
        ),
      );
      expect(limited.weeks, 1);
      expect(limited.warnings.join(), contains('Referencia limitada'));
    },
  );
  test(
    'source counts paid purchases once, excludes deposits/transfers and sums only external voucher lines',
    () {
      Map<String, dynamic> ticket(
        String id, {
        String status = 'PAGADO',
        String direction = 'purchase',
      }) => {
        'id': id,
        'ticket_date': '2026-09-14',
        'amount_total': 100,
        'status': status,
        'direction': direction,
      };
      Map<String, dynamic> voucher(
        String id,
        String rubric, {
        String type = 'expense',
        int lines = 0,
      }) => {
        'id': id,
        'voucher_date': '2026-09-14',
        'total_amount': 50,
        'voucher_type': type,
        'rubric': rubric,
        'line_count': lines,
      };
      final h = MenudeoExpenseHistory.fromRows(
        tickets: [
          ticket('a'),
          ticket('a'),
          ticket('b', status: 'PENDIENTE'),
          ticket('c', direction: 'sale'),
        ],
        vouchers: [
          voucher('d', 'OPERACION', type: 'deposit'),
          voucher('i', 'REPOSICIÓN DE FONDO'),
          voucher('e', 'OPERACION', lines: 2),
          voucher('f', 'OTROS'),
        ],
        lines: [
          {
            'id': 'l1',
            'voucher_id': 'e',
            'concept': 'COMBUSTIBLE',
            'amount': 30,
          },
          {'id': 'l2', 'voucher_id': 'e', 'concept': 'BÓVEDA', 'amount': 20},
          {
            'id': 'l1',
            'voucher_id': 'e',
            'concept': 'COMBUSTIBLE',
            'amount': 30,
          },
        ],
      );
      expect(h.movements.length, 3);
      expect(h.excludedInternal, 2);
      expect(h.movements.fold<int>(0, (s, r) => s + r.amount), 18000);
      expect(
        () => MenudeoExpenseHistory.fromRows(
          tickets: [],
          vouchers: [voucher('x', 'NORMAL', lines: 1)],
          lines: [],
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'repository pages history and passes weekly settings without persisting computed payments',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-test',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith(
            '/rpc/direction_save_weekly_projection',
          )) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['p_payments'], isEmpty);
            expect(body['p_menudeo_settings'], {
              'included': true,
              'purchases': 10001,
              'expenses': 0,
            });
            return http.Response(
              jsonEncode({
                'week_start': '2026-09-21',
                'revision': 1,
                'payments': [],
                'generated': true,
                'menudeo_settings': body['p_menudeo_settings'],
              }),
              200,
              request: request,
            );
          }
          if (request.url.path.endsWith('/vw_men_tickets_grid')) {
            final offset = int.parse(
              request.url.queryParameters['offset'] ?? '0',
            );
            final limit = int.parse(request.url.queryParameters['limit']!);
            final all = List.generate(
              1001,
              (i) => {
                'id': 'p$i',
                'ticket_date': '2026-09-14',
                'amount_total': 1,
                'status': 'PAGADO',
                'direction': 'purchase',
              },
            );
            return http.Response(
              jsonEncode(all.skip(offset).take(limit).toList()),
              200,
              request: request,
            );
          }
          return http.Response('[]', 200, request: request);
        }),
      );
      addTearDown(client.dispose);
      final repo = WeeklyProjectionRepository(client: client);
      final source = await repo.menudeoHistory(f.incomeWeek, f.incomeWeek);
      expect(source.movements.length, 1001);
      final query = requests.first.url.queryParametersAll;
      expect(
        query['ticket_date'],
        containsAll(['gte.2026-08-10', 'lt.2026-09-22']),
      );
      expect(query['direction'], ['eq.purchase']);
      expect(query['status'], ['eq.PAGADO']);
      final saved = await repo.save(
        plan(
          estimate(
            settings: const MenudeoExpenseSettings(
              purchases: 10001,
              expenses: 0,
            ),
          ),
        ),
      );
      expect(saved.menudeo.purchases, 10001);
      expect(saved.menudeo.expenses, 0);
    },
  );
  test(
    'failed Menudeo source propagates rather than becoming a zero forecast',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-test',
        httpClient: MockClient(
          (request) async =>
              http.Response('{"message":"denied"}', 403, request: request),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        WeeklyProjectionRepository(
          client: client,
        ).menudeoHistory(f.incomeWeek, f.incomeWeek),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
  test(
    'expense and flow PDFs include daily Menudeo aggregates once without ticket details',
    () async {
      final p = plan(estimate());
      expect(expenseReportPlan(p).total, 72000);
      final flow = WeeklyCashFlowReport(f.forecast(), p);
      expect(flow.flow.expenses, 72000);
      expect(flow.flow.closing, 7578000);
      final expenses = await buildWeeklyExpensesPdf(
        p,
        generatedAt: f.incomeWeek,
      );
      final cashFlow = await buildWeeklyCashFlowPdf(
        f.forecast(),
        p,
        generatedAt: f.incomeWeek,
      );
      expect(pdf.pages(expenses), greaterThanOrEqualTo(1));
      expect(pdf.pages(cashFlow), greaterThanOrEqualTo(2));
      if (Platform.environment['DICSA_MENUDEO_QA'] == '1') {
        await File(
          '/private/tmp/dicsa-menudeo-expenses.pdf',
        ).writeAsBytes(expenses);
        await File(
          '/private/tmp/dicsa-menudeo-flow.pdf',
        ).writeAsBytes(cashFlow);
      }
    },
  );
  testWidgets(
    'editable subdivision persists by week, reloads flow and blocks export on source error',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = expense_ui.MemoryProjectionRepository()..menudeo = history();
      final incomes = income_ui.MemoryIncomeRepository();
      final boundary = GlobalKey();
      Widget app({bool flow = false}) => RepaintBoundary(
        key: boundary,
        child: income_ui.app(
          WeeklyProjectionView(
            bundle: f.incomeBundle(),
            repository: repo,
            incomeRepository: incomes,
            clock: () => f.incomeWeek,
            active: true,
            flow: flow,
            onWeekChanged: (_) async {},
          ),
        ),
      );
      Future<void> capture(String name) async {
        if (Platform.environment['DICSA_MENUDEO_QA'] != '1') return;
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/private/tmp/dicsa-menudeo-$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Menudeo · efectivo estimado'), findsOneWidget);
      expect(
        find.text(r'Incluido en flujo: $720.00 · Efectivo'),
        findsOneWidget,
      );
      await capture('section');
      await tester.tap(find.byKey(const ValueKey('edit-menudeo-estimate')));
      await tester.pumpAndSettle();
      final purchases = find.byKey(const ValueKey('menudeoPurchases'));
      final expenses = find.byKey(const ValueKey('menudeoExpenses'));
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: purchases,
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        true,
      );
      await tester.enterText(purchases, '300');
      await tester.enterText(expenses, '0');
      await capture('editor');
      repo.failSave = true;
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('otra sesión'), findsOneWidget);
      expect(find.text('300'), findsOneWidget);
      repo.failSave = false;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(repo.saved[f.incomeWeek]!.menudeo.purchases, 30000);
      expect(repo.saved[f.incomeWeek]!.payments, isEmpty);
      expect(
        find.text(r'Incluido en flujo: $300.00 · Efectivo'),
        findsOneWidget,
      );
      await tester.pumpWidget(app(flow: true));
      await tester.pumpAndSettle();
      expect(find.text('De los cuales: Menudeo estimado'), findsOneWidget);
      expect(find.text(r'$300.00'), findsWidgets);
      await capture('flow');
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit-menudeo-estimate')));
      await tester.pumpAndSettle();
      expect(find.text('300.0'), findsOneWidget);
      await tester.enterText(purchases, '900');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repo.saved[f.incomeWeek]!.menudeo.purchases, 30000);
      repo.failMenudeo = true;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.textContaining('Menudeo no disponible'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('export-weekly-expenses')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
