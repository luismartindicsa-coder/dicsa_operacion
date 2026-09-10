import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dicsa_operacion/app/hr/human_resources_loans.dart';
import 'package:dicsa_operacion/app/hr/human_resources_loans_page.dart';
import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:dicsa_operacion/app/hr/human_resources_theme.dart';
import 'package:dicsa_operacion/app/shared/ui_contract_core/theme/area_theme_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const period = 'Periodo 37 semanal · 04/09/2026 - 10/09/2026';
const employee = {
  'id': 'test-1',
  'nombre': 'COLABORADOR DE PRUEBA',
  'empresa': 'DICSA',
  'salario': 2205.28,
  'salario_flujo': 1000,
  'employment_status': 'activo',
};

HrLoan loan({
  String id = 'loan-1',
  int folio = 1,
  num amount = 1200,
  int count = 4,
  String method = 'nomina',
  String channel = 'flujo',
  String first = '2026-09-04',
  String frequency = 'semanal',
  num? installmentAmount,
  num openingPaid = 0,
  int openingCount = 0,
  String issued = '2026-01-01',
  Map<String, dynamic> openingSnapshot = const {},
}) => HrLoan.fromRow({
  'id': id,
  'folio': folio,
  'employee_id': 'test-1',
  'employee_name': 'COLABORADOR DE PRUEBA',
  'empresa': 'DICSA',
  'principal': amount,
  'installment_count': count,
  'installment_amount': installmentAmount,
  'opening_paid_amount': openingPaid,
  'opening_paid_installments': openingCount,
  'opening_snapshot': openingSnapshot,
  'repayment_method': method,
  'payroll_channel': channel,
  'frequency': frequency,
  'issued_on': issued,
  'first_due_on': first,
});

HrLoanPayment payment(
  num amount, {
  String method = 'efectivo',
  String loanId = 'loan-1',
}) => HrLoanPayment.fromRow({
  'id': 'pay-$amount',
  'loan_id': loanId,
  'amount': amount,
  'method': method,
  'paid_on': '2026-09-05',
});

HrLoanFundState fund({
  List<HrLoan>? loans,
  List<HrLoanPayment> payments = const [],
}) => HrLoanFundState(
  capitalCents: 1500000,
  loans: loans ?? [loan()],
  payments: payments,
);

Map<String, dynamic> project({
  HrLoanFundState? state,
  Map<String, dynamic>? draft,
  Map<String, dynamic> person = employee,
  bool frozen = false,
}) => hrPrenominaPeriodProjectionForTesting(
  period: period,
  employees: [person],
  loanFund: state ?? fund(),
  freezeLoanPlans: frozen,
  drafts: draft == null ? [] : [draft],
  contpaq: [
    {'employee_id': 'test-1', 'net': '1700.00'},
  ],
).single;

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('HR_LOANS_PREVIEW')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '/private/tmp/dicsa_loans_$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('HR_LOANS_PREVIEW')) return;
    final bytes = File(
      '/opt/homebrew/share/flutter/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf',
    ).readAsBytesSync();
    for (final name in ['Ahem', 'Roboto']) {
      await (FontLoader(
        name,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    final icons = File(
      '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
  });

  test(
    'available fund derives from disbursements and both confirmed payment methods',
    () {
      final state = fund(
        payments: [
          payment(100),
          payment(200, method: 'nomina'),
        ],
      );
      expect(state.availableCents, 1410000);
      expect(state.balanceCents(state.loans.single), 90000);
      expect(state.recoveredCents, 30000);
      expect(fund().availableCents, 1380000);
    },
  );

  test(
    'installment rounding preserves every cent and monthly dates keep the original day',
    () {
      final item = loan(
        amount: 1000,
        count: 3,
        first: '2026-01-31',
        frequency: 'mensual',
      );
      expect(List.generate(3, item.installmentCents), [33333, 33333, 33334]);
      expect(List.generate(3, (i) => hrLoanDate(item.dueOn(i)!)), [
        '2026-01-31',
        '2026-02-28',
        '2026-03-31',
      ]);
    },
  );

  test(
    'opening balance keeps the original fixed payments and starts only in period 37',
    () {
      final item = loan(
        amount: 2500,
        count: 9,
        installmentAmount: 300,
        openingPaid: 600,
        openingCount: 2,
        issued: '2026-09-10',
        first: '2026-09-10',
        channel: 'fiscal',
        openingSnapshot: {
          'requested_on': '2026-08-17',
          'first_pending_period': period,
        },
      );
      final state = fund(loans: [item]);
      expect(List.generate(9, item.installmentCents), [
        30000,
        30000,
        30000,
        30000,
        30000,
        30000,
        30000,
        30000,
        10000,
      ]);
      expect(item.dueOn(0), isNull);
      expect(item.dueOn(1), isNull);
      expect(hrLoanDate(item.dueOn(2)!), '2026-09-10');
      expect(hrLoanDate(item.dueOn(8)!), '2026-10-22');
      expect(state.balanceCents(item), 190000);
      expect(state.dueCents(item, DateTime(2026, 8, 27)), 0);
      expect(state.dueCents(item, DateTime(2026, 9, 3)), 0);
      expect(state.dueCents(item, DateTime(2026, 9, 10)), 30000);
      expect(state.dueCents(item, DateTime(2026, 10, 22)), 190000);
      final after = fund(loans: [item], payments: [payment(300)]);
      expect(after.balanceCents(item), 160000);
      expect(after.dueCents(item, DateTime(2026, 9, 10)), 0);
      expect(after.dueCents(item, DateTime(2026, 9, 17)), 30000);
      final last = fund(loans: [item], payments: [payment(1800)]);
      expect(last.dueCents(item, DateTime(2026, 10, 22)), 10000);
      expect(project(state: state)['fiscal'], 1700);
      expect(
        project(
          state: state,
        )['payload']['source_snapshot']['loan_fund']['fiscal_amount'],
        300,
      );
    },
  );

  test(
    'six migrated balances reconcile the fund and the next payroll by channel',
    () {
      final specs = [
        (2500, 500, 5, 0, 0, 'fiscal'),
        (200, 200, 1, 0, 0, 'fiscal'),
        (2000, 250, 8, 0, 0, 'flujo'),
        (2500, 300, 9, 600, 2, 'fiscal'),
        (2000, 200, 10, 200, 1, 'fiscal'),
        (1500, 300, 5, 1200, 4, 'fiscal'),
      ];
      final state = fund(
        loans: [
          for (var i = 0; i < specs.length; i++)
            loan(
              id: 'loan-$i',
              folio: i + 1,
              amount: specs[i].$1,
              installmentAmount: specs[i].$2,
              count: specs[i].$3,
              openingPaid: specs[i].$4,
              openingCount: specs[i].$5,
              channel: specs[i].$6,
              issued: '2026-09-10',
              first: '2026-09-10',
              openingSnapshot: {'source': 'fixture'},
            ),
        ],
      );
      expect(state.lentCents, 1070000);
      expect(state.recoveredCents, 200000);
      expect(state.outstandingCents, 870000);
      expect(state.availableCents, 630000);
      final plan = state.payrollPlan(
        'test-1',
        DateTime(2026, 9, 10),
        flowAvailableCents: 59472,
        fiscalReady: true,
      );
      expect(plan.cents, 25000);
      expect(plan.fiscalCents, 150000);
      expect(plan.recoveredCents, 175000);
    },
  );

  test(
    'fiscal collection is informational at zero flow and survives repeat saves',
    () {
      final state = fund(loans: [loan(channel: 'fiscal')]);
      var row = project(
        state: state,
        person: {
          ...employee,
          'salario_flujo': 0,
          'fiscal_payment_mode': 'cheque',
        },
      );
      for (var i = 0; i < 3; i++) {
        expect(row['fiscal'], 1700);
        expect(row['fiscal_cash'], 1700);
        expect(row['total'], 1700);
        final payload = Map<String, dynamic>.from(row['payload']);
        expect(payload['loan_deduction_amount'], 0);
        expect(payload['source_snapshot']['loan_fund']['fiscal_amount'], 300);
        expect(payload['source_snapshot']['loan_fund']['pending_amount'], 0);
        row = project(
          state: state,
          draft: payload,
          person: {
            ...employee,
            'salario_flujo': 0,
            'fiscal_payment_mode': 'cheque',
          },
        );
      }
    },
  );

  test(
    'mixed channels only subtract flow and never consume its capacity for fiscal',
    () {
      final row = project(
        state: fund(
          loans: [
            loan(channel: 'fiscal'),
            loan(id: 'flow', folio: 2),
          ],
        ),
        draft: {
          'period_label': period,
          'employee_id': 'test-1',
          'loan_deduction_amount': 50,
        },
      );
      expect(row['fiscal'], 1700);
      expect(row['total'], 2350);
      expect(row['payload']['loan_deduction_amount'], 350);
      expect(
        row['payload']['source_snapshot']['loan_fund']['fiscal_amount'],
        300,
      );
    },
  );

  test(
    'fiscal quota waits for CONTPAQ and does not automatically switch channel',
    () {
      final state = fund(loans: [loan(channel: 'fiscal')]);
      final plan = state.payrollPlan(
        'test-1',
        DateTime(2026, 9, 10),
        flowAvailableCents: 100000,
      );
      expect(plan.cents, 0);
      expect(plan.fiscalCents, 0);
      expect(plan.pendingCents, 30000);
      final ready = state.payrollPlan(
        'test-1',
        DateTime(2026, 9, 10),
        flowAvailableCents: 0,
        fiscalReady: true,
      );
      expect(ready.fiscalCents, 30000);
      expect(ready.cents, 0);
      expect(ready.pendingCents, 0);
    },
  );

  test(
    'channel change recalculates an open draft and preserves manual loans and closed history',
    () {
      final original = project(
        draft: {
          'period_label': period,
          'employee_id': 'test-1',
          'loan_deduction_amount': 50,
        },
      );
      final payload = Map<String, dynamic>.from(original['payload']);
      final changed = fund(loans: [loan(channel: 'fiscal')]);
      final open = project(state: changed, draft: payload);
      expect(open['payload']['loan_deduction_amount'], 50);
      expect(
        open['payload']['source_snapshot']['loan_fund']['fiscal_amount'],
        300,
      );
      expect(open['total'], 2650);
      final closed = project(
        state: changed,
        draft: {...payload, 'draft_status': 'publicado'},
        frozen: true,
      );
      expect(closed['payload']['loan_deduction_amount'], 350);
      expect(
        closed['payload']['source_snapshot']['loan_fund']['fiscal_amount'],
        0,
      );
      expect(closed['total'], original['total']);
    },
  );

  test(
    'cash-only loans stay outside payroll, and advance payments reduce subsequent dues',
    () {
      final state = fund(
        loans: [
          loan(),
          loan(id: 'cash', folio: 2, method: 'efectivo'),
        ],
        payments: [payment(400)],
      );
      expect(
        state
            .payrollPlan(
              'test-1',
              DateTime(2026, 9, 10),
              flowAvailableCents: 100000,
            )
            .cents,
        0,
      );
      expect(
        state
            .payrollPlan(
              'test-1',
              DateTime(2026, 9, 17),
              flowAvailableCents: 100000,
            )
            .cents,
        20000,
      );
      expect(
        state
            .payrollPlan(
              'other',
              DateTime(2026, 9, 17),
              flowAvailableCents: 100000,
            )
            .cents,
        0,
      );
      expect(
        state
            .payrollPlan(
              'test-1',
              DateTime(2026, 8, 27),
              flowAvailableCents: 100000,
            )
            .cents,
        0,
      );
    },
  );

  test(
    'insufficient flow proposes only available money, leaves the rest pending, and does not recover it',
    () {
      final state = fund(
        loans: [
          loan(),
          loan(id: 'loan-2', folio: 2, amount: 800),
        ],
      );
      final plan = state.payrollPlan(
        'test-1',
        DateTime(2026, 9, 10),
        flowAvailableCents: 35000,
      );
      expect(plan.requestedCents, 50000);
      expect(plan.allocations.map((a) => a.cents), [30000, 5000]);
      expect(plan.pendingCents, 15000);
      expect(state.availableCents, 1300000);
      expect(
        state
            .payrollPlan(
              'test-1',
              DateTime(2026, 9, 10),
              flowAvailableCents: -500,
            )
            .cents,
        0,
      );
    },
  );

  test(
    'linked loan is added once beside legacy manual deduction; official fiscal is unchanged',
    () {
      var row = project(
        draft: {
          'period_label': period,
          'employee_id': 'test-1',
          'loan_deduction_amount': 50,
          'cash_salary_amount': 1000,
          'cash_salary_is_manual': true,
        },
      );
      expect(row['fiscal'], 1700);
      expect(row['total'], 2350);
      for (var i = 0; i < 3; i++) {
        final payload = row['payload'] as Map<String, dynamic>;
        expect(payload['loan_deduction_amount'], 350);
        expect(payload['source_snapshot']['loan_fund']['amount'], 300);
        row = project(draft: payload);
        expect(row['total'], 2350);
      }
    },
  );

  test(
    'zero flow keeps fiscal and cheque untouched and marks the installment pending',
    () {
      final row = project(
        person: {
          ...employee,
          'salario_flujo': 0,
          'fiscal_payment_mode': 'cheque',
        },
      );
      expect(row['fiscal'], 1700);
      expect(row['fiscal_cash'], 1700);
      expect(row['total'], 1700);
      final snapshot = row['payload']['source_snapshot']['loan_fund'];
      expect(snapshot['amount'], 0);
      expect(snapshot['pending_amount'], 300);
    },
  );

  test(
    'closed snapshot stays fixed after payments settle and future loans are created',
    () {
      final initial = project();
      final payload = Map<String, dynamic>.from(initial['payload'])
        ..['draft_status'] = 'publicado';
      final after = project(
        state: fund(payments: [payment(300, method: 'nomina')]),
        draft: payload,
        frozen: true,
      );
      expect(after['total'], initial['total']);
      expect(after['payload']['loan_deduction_amount'], 300);
      final open = project(
        state: fund(payments: [payment(300)]),
        draft: payload,
      );
      expect(open['payload']['loan_deduction_amount'], 0);
    },
  );

  test('outside payments cannot fund withholding from a fiscal cheque', () {
    final row = project(
      person: {
        ...employee,
        'salario_flujo': 0,
        'fiscal_payment_mode': 'cheque',
      },
      draft: {
        'period_label': period,
        'employee_id': 'test-1',
        'payment_outside_amount': 100,
      },
    );
    expect(row['fiscal'], 1700);
    expect(row['envelope'], 1700);
    expect(row['total'], 1800);
    expect(row['payload']['source_snapshot']['loan_fund']['amount'], 0);
  });

  testWidgets(
    'workspace shows the fund, selected schedule, cash action and searchable list',
    (tester) async {
      tester.view.physicalSize = const Size(1320, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var cashCalls = 0;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'Roboto'),
            home: AreaThemeScope(
              tokens: humanResourcesAreaTokens,
              child: Scaffold(
                backgroundColor: humanResourcesAreaTokens.primaryStrong,
                body: Padding(
                  padding: const EdgeInsets.all(24),
                  child: HrLoansWorkspace(
                    fund: fund(payments: [payment(100)]),
                    onCreate: () async {},
                    onCashPayment: (_) async {
                      cashCalls++;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(r'$13,900.00'), findsOneWidget);
      await tester.tap(find.text('COLABORADOR DE PRUEBA'));
      await tester.pumpAndSettle();
      expect(find.text('2026-09-04'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, boundary, 'workspace');
      await tester.tap(find.text('Abono en efectivo'));
      expect(cashCalls, 1);
      await tester.tap(find.text('Historial de abonos'));
      await tester.pumpAndSettle();
      expect(find.text(r'$100.00 · Efectivo'), findsOneWidget);
      final search = find.byType(TextField);
      await tester.enterText(search, 'NO EXISTE');
      await tester.pumpAndSettle();
      expect(find.text('No hay coincidencias.'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(tester.widget<TextField>(search).controller!.text, 'NO EXIST');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'historical loan shows prior payments without invented dates and the pending schedule',
    (tester) async {
      tester.view.physicalSize = const Size(1320, 980);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      final item = loan(
        amount: 2500,
        count: 9,
        installmentAmount: 300,
        openingPaid: 600,
        openingCount: 2,
        issued: '2026-09-10',
        first: '2026-09-10',
        channel: 'fiscal',
        openingSnapshot: {
          'requested_on': '2026-08-17',
          'first_pending_period': period,
        },
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'Roboto'),
            home: AreaThemeScope(
              tokens: humanResourcesAreaTokens,
              child: Scaffold(
                backgroundColor: humanResourcesAreaTokens.primaryStrong,
                body: Padding(
                  padding: const EdgeInsets.all(24),
                  child: HrLoansWorkspace(fund: fund(loans: [item])),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
      expect(find.text(r'$1,900.00'), findsWidgets);
      expect(find.text('Abono anterior · sin fecha'), findsNWidgets(2));
      expect(find.text('2026-09-10'), findsOneWidget);
      expect(find.text('2026-10-22'), findsOneWidget);
      expect(find.text(r'$100.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, boundary, 'opening_schedule');
      await tester.tap(find.text('Historial de abonos'));
      await tester.pumpAndSettle();
      expect(find.text(r'Abonos anteriores: $600.00'), findsOneWidget);
      expect(find.text('2/9 pagos al migrar · 2026-09-10'), findsOneWidget);
      expect(
        find.text('Aún no hay abonos nuevos registrados en la app.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, boundary, 'opening_history');
    },
  );

  testWidgets(
    'loan list preserves keyboard focus and arrows select the adjacent account',
    (tester) async {
      tester.view.physicalSize = const Size(1320, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: AreaThemeScope(
            tokens: humanResourcesAreaTokens,
            child: Scaffold(
              body: HrLoansWorkspace(
                fund: fund(
                  loans: [
                    loan(),
                    loan(id: 'loan-2', folio: 2),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListTile>(find.byType(ListTile).first).selected,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListTile>(find.byType(ListTile).last).selected,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListTile>(find.byType(ListTile).first).selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'new loan validates the fund, keeps one request and disables double submit',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      Map<String, dynamic>? submitted;
      final completer = Completer<String>();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'Roboto'),
            home: AreaThemeScope(
              tokens: humanResourcesAreaTokens,
              child: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    child: const Text('Abrir'),
                    onPressed: () {
                      showDialog<String>(
                        context: context,
                        builder: (_) => AreaThemeScope(
                          tokens: humanResourcesAreaTokens,
                          child: hrLoanCreateFormForTesting(
                            employees: [employee],
                            onSave: (parameters) {
                              calls++;
                              submitted = parameters;
                              return completer.future;
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seleccionar colaborador'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('ID #test-1'));
      await tester.pumpAndSettle();
      final amount = find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.labelText == 'Importe del préstamo',
      );
      await tester.enterText(amount, '15001');
      await tester.tap(find.text('Registrar entrega'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.enterText(amount, '2500');
      final installment = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Monto por abono (opcional)',
      );
      await tester.enterText(installment, '300');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Fiscal · CONTPAQ'));
      await tester.tap(find.text('Fiscal · CONTPAQ'));
      await tester.pumpAndSettle();
      await capture(tester, boundary, 'new_loan');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Registrar entrega'));
      await tester.pump();
      expect(calls, 1);
      expect(submitted!['p_principal'], 2500);
      expect(submitted!['p_installment_count'], 9);
      expect(submitted!['p_installment_amount'], 300);
      expect(submitted!['p_repayment_method'], 'nomina');
      expect(submitted!['p_payroll_channel'], 'fiscal');
      expect(submitted!['p_request_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      await tester.tap(find.text('Guardando…'));
      await tester.pump();
      expect(calls, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      completer.complete('loan-created');
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets(
    'existing loan channel selector sends an audited change and preserves its request on retry',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <Map<String, dynamic>>[];
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            debugShowCheckedModeBanner: false,
            home: AreaThemeScope(
              tokens: humanResourcesAreaTokens,
              child: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    child: const Text('Abrir'),
                    onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (_) => AreaThemeScope(
                        tokens: humanResourcesAreaTokens,
                        child: hrLoanChannelFormForTesting(
                          loan: loan(),
                          onSave: (parameters) async {
                            calls.add(parameters);
                            if (calls.length == 1) throw Exception('Retry');
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fiscal · CONTPAQ'));
      await tester.pumpAndSettle();
      await capture(tester, boundary, 'channel');
      await tester.tap(find.text('Guardar forma de cobro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar forma de cobro'));
      await tester.pumpAndSettle();
      expect(calls.length, 2);
      expect(calls[0]['p_request_id'], calls[1]['p_request_id']);
      expect(calls[1]['p_channel'], 'fiscal');
      expect(calls[1]['p_expected_channel'], 'flujo');
      expect(calls[1]['p_loan_id'], 'loan-1');
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'prenomina displays fiscal loan as informational and keeps its saved net',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final editor = hrPrenominaEditorForTesting(
        period: period,
        employee: employee,
        loanFund: fund(loans: [loan(channel: 'fiscal')]),
        storedDraft: {
          'period_label': period,
          'employee_id': 'test-1',
          'fiscal_net_amount': 1700,
          'cash_salary_amount': 1000,
          'cash_salary_is_manual': true,
          'source_snapshot': {'contpaq_official_net': 1700},
        },
      );
      Map<String, dynamic>? saved;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Abrir'),
                  onPressed: () async {
                    saved = await editor.open(context);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(
        find.text('Préstamo fiscal · incluido en CONTPAQ'),
        findsOneWidget,
      );
      await tester.tap(find.text('Descuentos'));
      await tester.pumpAndSettle();
      expect(
        find.text('Fiscal · ya incluido en CONTPAQ (informativo)'),
        findsOneWidget,
      );
      await capture(tester, boundary, 'prenomina_fiscal');
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(saved!['payload']['fiscal_net_amount'], 1700);
      expect(saved!['payload']['loan_deduction_amount'], 0);
      expect(
        saved!['payload']['source_snapshot']['loan_fund']['fiscal_amount'],
        300,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cash payment rejects excess and malformed amounts and emits exact cents',
    (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: AreaThemeScope(
            tokens: humanResourcesAreaTokens,
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Abrir'),
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (_) => AreaThemeScope(
                        tokens: humanResourcesAreaTokens,
                        child: hrLoanCashFormForTesting(
                          loan: loan(),
                          balanceCents: 120000,
                          onSave: (parameters) async {
                            submitted = parameters;
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      final amount = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Importe recibido',
      );
      for (final invalid in ['1201', '1,2', '100.001', '0', '-100']) {
        await tester.enterText(amount, invalid);
        await tester.tap(find.text('Registrar abono recibido'));
        await tester.pumpAndSettle();
        expect(submitted, isNull);
      }
      await tester.enterText(amount, '100.50');
      await tester.tap(find.text('Registrar abono recibido'));
      await tester.pumpAndSettle();
      expect(submitted!['p_amount'], 100.5);
      expect(submitted!['p_loan_id'], 'loan-1');
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
