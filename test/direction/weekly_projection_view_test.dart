import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/direction/projection/weekly_projection_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_repository.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_view.dart';
import 'package:dicsa_operacion/app/management_reports/finance_weekly_budget_analysis.dart';
import 'package:dicsa_operacion/app/finanzas/finanzas_provider_accounts_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';

import '../management_reports/finance_weekly_budget_fixtures.dart' as b;
import 'expected_income_test.dart' as f;
import 'expected_income_view_test.dart' as income;
import 'expected_income_export_test.dart' as exports;
import 'expected_income_pdf_test.dart' as pdf;
import 'weekly_projection_classification_test.dart' as classification;
import 'weekly_projection_test.dart' as projection;
import 'package:dicsa_operacion/app/direction/projection/menudeo_expense_projection.dart';

class MemoryProjectionRepository extends WeeklyProjectionRepository {
  MenudeoExpenseHistory menudeo = const MenudeoExpenseHistory();
  bool failMenudeo = false;
  @override
  Future<MenudeoExpenseHistory> menudeoHistory(
    DateTime week,
    DateTime now,
  ) async {
    if (failMenudeo) throw StateError('Menudeo no disponible');
    return menudeo;
  }

  final Map<DateTime, WeeklyExpensePlan> saved = {};
  bool fail = false, failSave = false;
  bool includeTickets = false;
  bool includeAgreements = false;
  FinanceWeeklyBudgetSource? sourceOverride;
  List<FinanzasSupplierInvoiceRecord>? invoices;
  int writes = 0;
  @override
  Future<WeeklyExpensePlan> load(DateTime week) async {
    if (fail) throw StateError('Finanzas no disponible');
    return saved[week] ?? WeeklyExpensePlan(week: week);
  }

  @override
  Future<FinanceWeeklyBudgetAnalysis> proposal(
    DateTime week,
    DateTime now,
  ) async => FinanceWeeklyBudgetAnalysis(
    sourceOverride ??
        b.budgetSource(
          invoices: invoices ?? [b.invoice('invoice-1', 10000, '2026-09-24')],
          fixedPayments: [
            b.fixed('fixed-1', 2500, '2026-09-25', method: 'EFECTIVO'),
          ],
          tickets: includeTickets
              ? [classification.ticket('cash-ticket')]
              : const [],
          agreements: includeAgreements
              ? [
                  for (final status in ['ACTIVO', 'CUMPLIDO', 'CANCELADO'])
                    FinanzasSupplierAgreementRecord.fromRemoteRow({
                      'id': 'agreement-$status',
                      'provider_id': 'provider-$status',
                      'provider_name_snapshot': 'CONVENIO $status',
                      'agreement_type': 'POR_FACTURAS',
                      'status': status,
                      'target_company': 'DICSA',
                      'target_branch': 'CELAYA',
                      'remaining_amount': status == 'CUMPLIDO' ? 0 : 1800,
                    }),
                ]
              : const [],
          installments: includeAgreements
              ? [
                  for (final status in ['ACTIVO', 'CUMPLIDO', 'CANCELADO'])
                    FinanzasSupplierAgreementInstallmentRecord.fromRemoteRow({
                      'id': 'installment-$status',
                      'agreement_id': 'agreement-$status',
                      'sequence_number': 1,
                      'due_date': '2026-09-24',
                      'amount': 1000,
                      'paid_amount': status == 'CUMPLIDO' ? 1000 : 200,
                      'status': status == 'CUMPLIDO' ? 'PAGADO' : 'PENDIENTE',
                    }),
                  FinanzasSupplierAgreementInstallmentRecord.fromRemoteRow({
                    'id': 'future',
                    'agreement_id': 'agreement-ACTIVO',
                    'sequence_number': 2,
                    'due_date': '2026-10-01',
                    'amount': 1000,
                    'paid_amount': 0,
                    'status': 'PENDIENTE',
                  }),
                ]
              : const [],
        ),
    now,
    targetWeek: week,
  );
  @override
  Future<WeeklyExpensePlan> save(WeeklyExpensePlan plan) async {
    if (failSave) throw StateError('La proyección cambió en otra sesión');
    writes++;
    return saved[plan.week] = WeeklyExpensePlan(
      menudeo: plan.menudeo,
      week: plan.week,
      revision: plan.revision + 1,
      payments: plan.payments,
      openingCash: plan.openingCash,
      openingFiscal: plan.openingFiscal,
      generated: plan.generated,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Roboto', 'Ahem']) {
      final loader = FontLoader(family)
        ..addFont(
          Future.value(
            ByteData.sublistView(
              await File('assets/fonts/Roboto-Regular.ttf').readAsBytes(),
            ),
          ),
        );
      await loader.load();
    }
  });
  Future<void> size(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1050));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget harness(
    MemoryProjectionRepository repo, {
    bool flow = false,
    income.MemoryIncomeRepository? incomes,
    GlobalKey? boundary,
    String? error,
  }) => income.app(
    RepaintBoundary(
      key: boundary,
      child: WeeklyProjectionView(
        bundle: f.incomeBundle(stock: {'PACA_NACIONAL': 50}),
        repository: repo,
        incomeRepository: incomes ?? income.MemoryIncomeRepository(),
        flow: flow,
        active: true,
        referenceError: error,
        clock: () => f.incomeWeek,
        onWeekChanged: (_) async {},
      ),
    ),
  );
  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (Platform.environment['DICSA_FLOW_QA'] != '1') return;
    await tester.runAsync(() async {
      final picture =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      final data = await picture.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/private/tmp/dicsa-projection-$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      picture.dispose();
    });
  }

  testWidgets(
    'generate, edit, focus, Enter and refresh preserve final amount; Escape cancels',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository();
      final key = GlobalKey();
      await tester.pumpWidget(harness(repo, boundary: key));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('generate-projected-payments')),
      );
      await tester.pumpAndSettle();
      expect(repo.saved[f.incomeWeek]!.payments.length, 2);
      await tester.ensureVisible(
        find.byKey(const ValueKey('edit-payment-invoice:invoice-1')),
      );
      await tester.tap(
        find.byKey(const ValueKey('edit-payment-invoice:invoice-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('amount')));
      await tester.enterText(find.byKey(const ValueKey('amount')), '4321.25');
      await tester.pump(const Duration(seconds: 31));
      expect(find.text('4321.25'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        repo.saved[f.incomeWeek]!.payments
            .firstWhere((p) => p.source == 'invoice')
            .amount,
        432125,
      );
      await tester.tap(
        find.byKey(const ValueKey('edit-payment-invoice:invoice-1')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('amount')), '9999');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repo.writes, 2);
      await capture(tester, key, 'expenses');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'payment classification and date picker persist into the weekly flow',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository();
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('generate-projected-payments')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('edit-payment-invoice:invoice-1')),
      );
      await tester.tap(
        find.byKey(const ValueKey('edit-payment-invoice:invoice-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tipo de salida: Fiscal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Efectivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fecha de pago: 2026-09-24 · Jueves'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026-09-22 · Martes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final payment = repo.saved[f.incomeWeek]!.payments.firstWhere(
        (r) => r.source == 'invoice',
      );
      expect(payment.paymentType, 'EFECTIVO');
      expect(payment.paymentTypeAutomatic, isFalse);
      expect(payment.date, DateTime(2026, 9, 22));
      await tester.pumpWidget(harness(repo, flow: true));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hay ingresos mixtos'), findsNothing);
      expect(find.text(r'$12,500.00'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'new sin factura ticket keeps its Finance cash classification when programmed',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository()..includeTickets = true;
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('generate-projected-payments')),
      );
      await tester.pumpAndSettle();
      final initial = repo.saved[f.incomeWeek]!.payments.firstWhere(
        (r) => r.source == 'ticket',
      );
      expect(initial.paymentType, 'EFECTIVO');
      expect(initial.included, isFalse);
      await tester.tap(find.text('Mostrar solo pagos incluidos'));
      await tester.pumpAndSettle();
      final edit = find.byKey(
        const ValueKey('edit-payment-ticket:cash-ticket'),
      );
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.text('Tipo de salida: Efectivo'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('amount')), '500');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final saved = repo.saved[f.incomeWeek]!.payments.firstWhere(
        (r) => r.source == 'ticket',
      );
      expect(saved.included, isTrue);
      expect(saved.total, 50000);
      expect(saved.paymentType, 'EFECTIVO');
      expect(saved.paymentTypeAutomatic, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'add expense searches Finance agreements with focus and prefills remaining balance and date',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository()..includeAgreements = true;
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-projected-expense')));
      await tester.pumpAndSettle();
      expect(
        find.text('Agregar egreso · Facturas y convenios de Finanzas'),
        findsOneWidget,
      );
      expect(find.textContaining('CONVENIO CUMPLIDO'), findsNothing);
      expect(find.textContaining('CONVENIO CANCELADO'), findsNothing);
      expect(find.textContaining('cuota 2'), findsNothing);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byType(Dialog),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      tester.testTextInput.enterText('CONVENIO ACTIVO');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.textContaining('Saldo \$800.00'), findsOneWidget);
      await tester.tap(
        find.textContaining('CONVENIO ACTIVO · Convenio / cuota 1'),
      );
      await tester.pumpAndSettle();
      expect(find.text('800.0'), findsOneWidget);
      expect(find.text('Tipo de salida: Fiscal'), findsOneWidget);
      expect(find.text('Fecha de pago: 2026-09-24 · Jueves'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('amount')), '900');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(repo.writes, 0, reason: 'Cannot exceed the remaining installment');
      await tester.enterText(find.byKey(const ValueKey('amount')), '750');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final payment = repo.saved[f.incomeWeek]!.payments.single;
      expect(payment.id, 'agreement:installment-ACTIVO');
      expect(payment.source, 'agreement');
      expect(payment.amount, 75000);
      expect(payment.paymentType, 'FISCAL');
      expect(payment.date, DateTime(2026, 9, 24));
      expect(payment.included, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'invoice picker searches folio, supplier and account, then saves a partial Fiscal payment',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository()
        ..invoices = [
          b.invoice(
            'F-425',
            10000,
            '2026-09-24',
            provider: 'Papelera Norte',
            balance: 4250,
          ),
          b.invoice('PAGADA', 10000, '2026-09-24', status: 'PAGADA'),
          b.invoice('CANCELADA', 10000, '2026-09-24', status: 'CANCELADA'),
          b.invoice('SIN-SALDO', 10000, '2026-09-24', balance: 0),
          b.invoice('EN-CONVENIO', 10000, '2026-09-24', status: 'CONVENIO'),
          b.invoice(
            'CONVENIO-SIN-CUENTA',
            10000,
            '2026-09-24',
            status: 'CONVENIO',
            company: '',
          ),
        ];
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-projected-expense')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ya programado'), findsNothing);
      final search = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      for (final query in ['f-425', 'papelera norte', 'dicsa / celaya']) {
        await tester.enterText(search, query);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Factura F-425 · Papelera Norte'),
          findsOneWidget,
        );
      }
      expect(find.textContaining(r'Saldo $4,250.00'), findsOneWidget);
      await tester.enterText(search, 'f-425');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('4250.0'), findsOneWidget);
      expect(find.text('Tipo de salida: Fiscal'), findsOneWidget);
      expect(find.text('Fecha de pago: 2026-09-24 · Jueves'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('amount')), '5000');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(repo.writes, 0);
      await tester.enterText(find.byKey(const ValueKey('amount')), '4000');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final saved = repo.saved[f.incomeWeek]!.payments.single;
      expect(saved.id, 'invoice:F-425');
      expect(saved.source, 'invoice');
      expect(saved.payee, 'Papelera Norte');
      expect(saved.amount, 400000);
      expect(saved.available, 425000);
      expect(saved.paymentType, 'FISCAL');
      expect(saved.paymentTypeAutomatic, true);
      expect(saved.included, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'selecting an existing invoice preserves adjustments and saves without duplication',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository();
      final invoice =
          paymentProposal(await repo.proposal(f.incomeWeek, f.incomeWeek))
              .singleWhere((r) => r.source == 'invoice')
              .copyWith(
                amount: 70000,
                date: DateTime(2026, 9, 22),
                paymentType: 'EFECTIVO',
                paymentTypeAutomatic: false,
                notes: 'Conservar abono',
              );
      repo.saved[f.incomeWeek] = WeeklyExpensePlan(
        week: f.incomeWeek,
        payments: [invoice],
      );
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-projected-expense')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Ya programado'));
      await tester.pumpAndSettle();
      expect(find.text('700.0'), findsOneWidget);
      expect(find.text('Tipo de salida: Efectivo'), findsOneWidget);
      expect(find.text('Fecha de pago: 2026-09-22 · Martes'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('amount')), '650');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final saved = repo.saved[f.incomeWeek]!.payments.single;
      expect(saved.id, invoice.id);
      expect(saved.amount, 65000);
      expect(saved.notes, 'Conservar abono');
      expect(saved.paymentType, 'EFECTIVO');
      expect(saved.paymentTypeAutomatic, false);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'invoice removed from the week can be explicitly restored with its current balance',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository();
      final invoice = paymentProposal(
        await repo.proposal(f.incomeWeek, f.incomeWeek),
      ).singleWhere((r) => r.source == 'invoice');
      repo.saved[f.incomeWeek] = WeeklyExpensePlan(
        week: f.incomeWeek,
        payments: [invoice.copyWith(removed: true, included: false)],
      );
      repo.invoices = [
        b.invoice('invoice-1', 10000, '2026-09-24', balance: 3500),
      ];
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-projected-expense')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ya programado'), findsNothing);
      await tester.tap(find.textContaining('Factura invoice-1 · Proveedor A'));
      await tester.pumpAndSettle();
      expect(find.text('3500.0'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final saved = repo.saved[f.incomeWeek]!.payments.single;
      expect(saved.id, invoice.id);
      expect(saved.removed, false);
      expect(saved.included, true);
      expect(saved.total, 350000);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'invoice outside the automatic proposal can be scheduled and cancelling leaves it untouched',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository()
        ..invoices = [b.invoice('F-FUTURA', 800, '2026-10-01')];
      final candidate = paymentProposal(
        await repo.proposal(f.incomeWeek, f.incomeWeek),
      ).singleWhere((r) => r.source == 'invoice');
      expect(candidate.included, false);
      expect(candidate.amount, 0);
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      Future<void> select() async {
        await tester.tap(find.byKey(const ValueKey('add-projected-expense')));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Factura F-FUTURA · Proveedor A'));
        await tester.pumpAndSettle();
      }

      await select();
      expect(find.textContaining('Vence después de la semana'), findsOneWidget);
      expect(find.text('800.0'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repo.writes, 0);
      await select();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final saved = repo.saved[f.incomeWeek]!.payments.single;
      expect(saved.date, DateTime(2026, 9, 27));
      expect(saved.total, 80000);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('manual entry remains available with no invoices or agreements', (
    tester,
  ) async {
    await size(tester);
    final repo = MemoryProjectionRepository()..invoices = [];
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-projected-expense')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Sin facturas o convenios disponibles'),
      findsOneWidget,
    );
    await tester.tap(find.text('Capturar egreso manual'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('payee')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(repo.writes, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'selecting an already programmed agreement edits the original and preserves manual choices',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository()..includeAgreements = true;
      final agreement =
          paymentProposal(await repo.proposal(f.incomeWeek, f.incomeWeek))
              .singleWhere((r) => r.source == 'agreement')
              .copyWith(
                amount: 30000,
                included: true,
                date: DateTime(2026, 9, 23),
                paymentType: 'EFECTIVO',
                paymentTypeAutomatic: false,
                notes: 'Conservar nota',
              );
      repo.saved[f.incomeWeek] = WeeklyExpensePlan(
        week: f.incomeWeek,
        revision: 1,
        generated: true,
        payments: [agreement],
      );
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-projected-expense')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Ya programado'));
      await tester.pumpAndSettle();
      expect(find.text('300.0'), findsOneWidget);
      expect(find.text('Tipo de salida: Efectivo'), findsOneWidget);
      expect(
        find.text('Fecha de pago: 2026-09-23 · Miércoles'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const ValueKey('amount')), '400');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final saved = repo.saved[f.incomeWeek]!.payments.single;
      expect(saved.id, agreement.id);
      expect(saved.amount, 40000);
      expect(saved.notes, 'Conservar nota');
      expect(saved.paymentType, 'EFECTIVO');
      expect(saved.paymentTypeAutomatic, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'cancel agreement selector or prefilled editor leaves the weekly projection untouched',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository()..includeAgreements = true;
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-projected-expense')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repo.writes, 0);
      await tester.tap(find.byKey(const ValueKey('add-projected-expense')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining('CONVENIO ACTIVO · Convenio / cuota 1'),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'manual capture remains available alongside Finance invoices and agreements',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository()..includeAgreements = true;
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-projected-expense')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Facturas y convenios de Finanzas'),
        findsOneWidget,
      );
      await tester.tap(find.text('Capturar egreso manual'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('payee')),
        'Gasto adicional',
      );
      await tester.enterText(find.byKey(const ValueKey('amount')), '250');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final saved = repo.saved[f.incomeWeek]!.payments.single;
      expect(saved.source, 'manual');
      expect(saved.payee, 'GASTO ADICIONAL');
      expect(saved.total, 25000);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'failed save retains the edit and permits retry without resetting input',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository();
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('generate-projected-payments')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('edit-payment-invoice:invoice-1')),
      );
      await tester.tap(
        find.byKey(const ValueKey('edit-payment-invoice:invoice-1')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('amount')), '500');
      repo.failSave = true;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.textContaining('otra sesión'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      repo.failSave = false;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        repo.saved[f.incomeWeek]!.payments
            .firstWhere((p) => p.source == 'invoice')
            .amount,
        50000,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'opening balances recalculate flow, missing classification remains explicit, source failures block export',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository();
      final key = GlobalKey();
      repo.saved[f.incomeWeek] = WeeklyExpensePlan(
        week: f.incomeWeek,
        revision: 1,
        generated: true,
        payments: paymentProposal(
          await repo.proposal(f.incomeWeek, f.incomeWeek),
        ),
      );
      await tester.pumpWidget(harness(repo, flow: true, boundary: key));
      await tester.pumpAndSettle();
      expect(find.text('Sin saldo inicial'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('projection-opening')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('cash')), '10000');
      await tester.enterText(find.byKey(const ValueKey('fiscal')), '20000');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(repo.saved[f.incomeWeek]!.openingCash, 1000000);
      expect(repo.saved[f.incomeWeek]!.openingFiscal, 2000000);
      expect(
        find.text(r'$100,000.00'),
        findsWidgets,
      ); // 82,500 income -12,500 payments +30,000 opening
      await capture(tester, key, 'flow');
      await tester.binding.setSurfaceSize(const Size(780, 1000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      repo.fail = true;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.textContaining('última lectura'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('export-weekly-flow')),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'delete cancellation, failed save and durable removal of a Finance payment',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository();
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('generate-projected-payments')),
      );
      await tester.pumpAndSettle();
      final remove = find.byKey(
        const ValueKey('delete-payment-invoice:invoice-1'),
      );
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('registros originales de Finanzas se conservan'),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repo.writes, 1);
      expect(repo.saved[f.incomeWeek]!.total, 1250000);
      repo.failSave = true;
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar egreso'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo guardar'), findsOneWidget);
      expect(remove, findsOneWidget);
      expect(repo.saved[f.incomeWeek]!.total, 1250000);
      repo.failSave = false;
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(remove, findsNothing);
      expect(
        repo.saved[f.incomeWeek]!.payments
            .firstWhere((p) => p.source == 'invoice')
            .removed,
        true,
      );
      expect(repo.saved[f.incomeWeek]!.total, 250000);
      // Incorporate genuinely new pending items without resurrecting the removal.
      repo.includeTickets = true;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('generate-projected-payments')),
      );
      await tester.tap(
        find.byKey(const ValueKey('generate-projected-payments')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mostrar solo pagos incluidos'));
      await tester.pumpAndSettle();
      expect(remove, findsNothing);
      expect(
        repo.saved[f.incomeWeek]!.payments.where((p) => p.source == 'ticket'),
        hasLength(1),
      );
      expect(
        repo.saved[f.incomeWeek]!.payments.where((p) => p.source == 'invoice'),
        hasLength(1),
      );
      expect(repo.saved[f.incomeWeek]!.total, 250000);
      await tester.pumpWidget(const SizedBox());
      // Reopening the flow reflects the saved removal (82,500 - 2,500).
      await tester.pumpWidget(harness(repo, flow: true));
      await tester.pumpAndSettle();
      expect(find.text(r'$80,000.00'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'manual expense delete removes only this week and respects source errors',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository();
      final manual = projection.payment('manual:one', 12300);
      final nextWeek = f.incomeWeek.add(const Duration(days: 7));
      repo.saved[f.incomeWeek] = WeeklyExpensePlan(
        week: f.incomeWeek,
        payments: [manual],
      );
      repo.saved[nextWeek] = WeeklyExpensePlan(
        week: nextWeek,
        payments: [manual.copyWith(date: nextWeek)],
      );
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      final remove = find.byKey(const ValueKey('delete-payment-manual:one'));
      repo.fail = true;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(remove).onPressed, isNull);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('export-weekly-expenses')),
            )
            .onPressed,
        isNull,
      );
      repo.fail = false;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar egreso'));
      await tester.pumpAndSettle();
      expect(repo.saved[f.incomeWeek]!.payments, isEmpty);
      expect(repo.saved[nextWeek]!.payments.single.amount, 12300);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a removed agreement can be deliberately added again without duplication',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository()..includeAgreements = true;
      final agreement = paymentProposal(
        await repo.proposal(f.incomeWeek, f.incomeWeek),
      ).firstWhere((p) => p.source == 'agreement');
      repo.saved[f.incomeWeek] = WeeklyExpensePlan(
        week: f.incomeWeek,
        payments: [agreement.copyWith(removed: true, included: false)],
      );
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-projected-expense')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('CONVENIO ACTIVO').last);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(repo.saved[f.incomeWeek]!.payments, hasLength(1));
      expect(repo.saved[f.incomeWeek]!.payments.single.removed, false);
      expect(repo.saved[f.incomeWeek]!.total, 80000);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'expense PDF exports selected week, handles cancel and failure without changing the plan',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository();
      final dir = Directory.systemTemp.createTempSync('expenses-export-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final picker = exports.IncomeSavePicker()..path = '${dir.path}/egresos';
      FilePicker.platform = picker;
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('generate-projected-payments')),
      );
      await tester.pumpAndSettle();
      Future<void> export() async {
        final action = tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('export-weekly-expenses')),
            )
            .onPressed!;
        await tester.runAsync(action as Future<void> Function());
        await tester.pumpAndSettle();
      }

      await export();
      expect(picker.name, 'egresos_proyectados_2026-09-21.pdf');
      expect(pdf.pages(File('${dir.path}/egresos.pdf').readAsBytesSync()), 1);
      expect(find.textContaining('PDF guardado en'), findsOneWidget);
      picker.path = null;
      await export();
      expect(find.textContaining('se canceló la selección'), findsOneWidget);
      picker.error = const FileSystemException('Sin permiso para guardar');
      await export();
      expect(
        find.textContaining('No se pudo generar o guardar el PDF'),
        findsOneWidget,
      );
      expect(repo.writes, 1);
      expect(repo.saved[f.incomeWeek]!.total, 1250000);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('export-weekly-expenses')),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'flow PDF export writes detailed pages with selected week filename',
    (tester) async {
      await size(tester);
      final repo = MemoryProjectionRepository();
      final dir = Directory.systemTemp.createTempSync('flow-export-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final picker = exports.IncomeSavePicker()..path = '${dir.path}/flujo';
      FilePicker.platform = picker;
      await tester.pumpWidget(harness(repo, flow: true));
      await tester.pumpAndSettle();
      final action = tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('export-weekly-flow')),
          )
          .onPressed!;
      await tester.runAsync(action as Future<void> Function());
      await tester.pumpAndSettle();
      expect(picker.name, 'flujo_semanal_proyectado_2026-09-21.pdf');
      expect(
        pdf.pages(File('${dir.path}/flujo.pdf').readAsBytesSync()),
        greaterThan(1),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
