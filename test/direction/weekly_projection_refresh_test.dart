import 'dart:io';

import 'package:dicsa_operacion/app/direction/projection/weekly_projection_models.dart';
import 'package:dicsa_operacion/app/direction/projection/weekly_projection_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../management_reports/finance_weekly_budget_fixtures.dart' as finance;
import 'expected_income_test.dart' as f;
import 'expected_income_view_test.dart' as income;
import 'weekly_projection_view_test.dart' as fixtures;

ProjectedPayment payment(
  String id, {
  int amount = 10000,
  bool automatic = true,
  bool included = true,
  bool removed = false,
  String source = 'invoice',
  String notes = '',
}) => ProjectedPayment(
  id: id,
  source: source,
  payee: id,
  reference: id,
  account: 'DICSA|CELAYA',
  date: f.incomeWeek,
  amount: amount,
  available: 100000,
  included: included,
  removed: removed,
  paymentType: 'FISCAL',
  paymentTypeAutomatic: true,
  selectionAutomatic: automatic,
  notes: notes,
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
  });
  test(
    'incorporation reselects existing automatic zero candidates without duplicates',
    () {
      final saved = [payment('existing', amount: 0, included: false)];
      final current = [
        payment('existing', amount: 70000),
        payment('new', amount: 20000),
      ];
      final result = incorporateFinanceProposal(saved, current);
      expect(result.length, 2);
      expect(result.fold<int>(0, (sum, r) => sum + r.total), 90000);
      final repeated = incorporateFinanceProposal(result, current);
      expect(repeated.map((r) => r.toJson()), result.map((r) => r.toJson()));
    },
  );
  test(
    'explicit amounts, date, notes, exclusion and removal survive new Friday selection',
    () {
      final adjusted =
          payment(
            'edited',
            amount: 12345,
            automatic: false,
            notes: 'Conservar',
          ).copyWith(
            date: f.incomeWeek.add(const Duration(days: 4)),
            paymentType: 'EFECTIVO',
            paymentTypeAutomatic: false,
          );
      final excluded = payment('excluded', automatic: false, included: false);
      final removed = payment(
        'removed',
        automatic: false,
        included: false,
        removed: true,
      );
      final manual = payment('manual', source: 'manual', automatic: false);
      final result = incorporateFinanceProposal(
        [adjusted, excluded, removed, manual],
        [
          for (final id in ['edited', 'excluded', 'removed'])
            payment(id, amount: 90000),
        ],
      );
      expect(result[0].amount, 12345);
      expect(result[0].date, adjusted.date);
      expect(result[0].notes, 'Conservar');
      expect(result[0].paymentType, 'EFECTIVO');
      expect(result[1].included, false);
      expect(result[2].removed, true);
      expect(result[3].toJson(), manual.toJson());
    },
  );
  test(
    'obsolete auto selection changes only on incorporation and paid obligations remain excluded',
    () {
      final saved = payment('a', amount: 50000);
      final current = payment('a', amount: 0, included: false);
      expect(reconcilePayments([saved], [current]).single.amount, 50000);
      expect(incorporateFinanceProposal([saved], [current]).single.total, 0);
      expect(incorporateFinanceProposal([saved], []).single.total, 0);
      final capped = incorporateFinanceProposal(
        [saved.copyWith(selectionAutomatic: false)],
        [current.copyWith(available: 500)],
      ).single;
      expect(capped.amount, 500);
    },
  );
  test(
    'legacy zero candidates can recover; legacy manual exclusions and removals stay protected',
    () {
      Map<String, dynamic> legacy(ProjectedPayment p) =>
          p.toJson()..remove('selection_automatic');
      final zero = ProjectedPayment.fromJson(
        legacy(payment('a', amount: 0, included: false)),
      );
      expect(zero.selectionAutomatic, true);
      expect(
        incorporateFinanceProposal([zero], [payment('a')]).single.total,
        10000,
      );
      for (final row in [
        payment('a', included: false),
        payment('a', included: false, removed: true),
        payment('a', amount: 0, included: false, notes: 'Excluido'),
        payment('a', source: 'manual', amount: 0, included: false),
      ]) {
        expect(
          ProjectedPayment.fromJson(legacy(row)).selectionAutomatic,
          false,
        );
      }
      final explicit = payment(
        'a',
        amount: 0,
        included: false,
        automatic: false,
      );
      expect(
        ProjectedPayment.fromJson(explicit.toJson()).selectionAutomatic,
        false,
      );
    },
  );
  test(
    'explicit reset restores Finance selection and replaces only Finance adjustments',
    () {
      final manual = payment(
        'manual:keep',
        source: 'manual',
        automatic: false,
        included: false,
        notes: 'Capturado manualmente',
      );
      final saved = [
        payment('removed', included: false, removed: true, automatic: false),
        payment('excluded', included: false, automatic: false),
        payment('edited', amount: 123, automatic: false, notes: 'Ajustado'),
        payment('no-longer-pending', included: false, removed: true),
        manual,
      ];
      final current = [
        payment('removed', amount: 8000),
        payment('excluded', amount: 9000),
        payment('edited', amount: 30000),
        payment('future', amount: 0, included: false),
      ];
      final restored = resetFinanceProposal(saved, current);
      expect(
        restored.map((r) => r.toJson()),
        [...current, manual].map((r) => r.toJson()),
      );
      expect(restored.fold<int>(0, (sum, r) => sum + r.total), 47000);
      expect(restored.any((r) => r.removed), false);
      final roundTrip = restored
          .map((r) => ProjectedPayment.fromJson(r.toJson()))
          .toList();
      expect(
        incorporateFinanceProposal(roundTrip, current).map((r) => r.toJson()),
        restored.map((r) => r.toJson()),
      );
      expect(
        resetFinanceProposal(restored, current).map((r) => r.toJson()),
        restored.map((r) => r.toJson()),
      );
      expect(resetFinanceProposal(saved, []).single.toJson(), manual.toJson());
    },
  );
  testWidgets(
    'button consults fresh Finance source, updates existing zeros and preserves settings',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = fixtures.MemoryProjectionRepository();
      final initial = paymentProposal(
        await repo.proposal(f.incomeWeek, f.incomeWeek),
      );
      repo.saved[f.incomeWeek] = WeeklyExpensePlan(
        week: f.incomeWeek,
        generated: true,
        revision: 3,
        openingCash: 12345,
        openingFiscal: 67890,
        menudeo: const MenudeoExpenseSettings(purchases: 100, expenses: 200),
        payments: [
          for (final r in initial)
            r.source == 'invoice'
                ? r.copyWith(amount: 0, included: false)
                : r.copyWith(amount: 10000, selectionAutomatic: false),
        ],
      );
      await tester.pumpWidget(
        income.app(
          WeeklyProjectionView(
            bundle: f.incomeBundle(),
            repository: repo,
            incomeRepository: income.MemoryIncomeRepository(),
            flow: false,
            active: true,
            clock: () => f.incomeWeek,
            onWeekChanged: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Generar propuesta de pagos'), findsOneWidget);
      repo.invoices = [
        finance.invoice('invoice-1', 10000, '2026-09-24'),
        finance.invoice('fresh', 300, '2026-09-24', provider: 'NEW'),
      ];
      await tester.tap(
        find.byKey(const ValueKey('generate-projected-payments')),
      );
      await tester.pumpAndSettle();
      final saved = repo.saved[f.incomeWeek]!;
      expect(saved.payments.length, 3);
      expect(
        saved.payments.singleWhere((r) => r.id == 'invoice:invoice-1').total,
        1000000,
      );
      expect(
        saved.payments.singleWhere((r) => r.id == 'invoice:fresh').total,
        30000,
      );
      expect(
        saved.payments.singleWhere((r) => r.source == 'fixed').amount,
        10000,
      );
      expect(saved.openingCash, 12345);
      expect(saved.openingFiscal, 67890);
      expect(saved.menudeo.purchases, 100);
      expect(saved.menudeo.expenses, 200);
      expect(
        find.textContaining('Proyección actualizada desde Finanzas'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('generate-projected-payments')),
      );
      await tester.pumpAndSettle();
      expect(repo.saved[f.incomeWeek]!.payments.length, 3);
      expect(find.text('Generar propuesta de pagos'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'manual exclusion remains excluded after incorporation and explains result',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = fixtures.MemoryProjectionRepository();
      final rows = paymentProposal(
        await repo.proposal(f.incomeWeek, f.incomeWeek),
      );
      repo.saved[f.incomeWeek] = WeeklyExpensePlan(
        week: f.incomeWeek,
        generated: true,
        payments: rows,
      );
      await tester.pumpWidget(
        income.app(
          WeeklyProjectionView(
            bundle: f.incomeBundle(),
            repository: repo,
            incomeRepository: income.MemoryIncomeRepository(),
            flow: false,
            active: true,
            clock: () => f.incomeWeek,
            onWeekChanged: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final edit = find.byKey(const ValueKey('edit-payment-invoice:invoice-1'));
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Incluir en el flujo de la semana'));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(
        repo.saved[f.incomeWeek]!.payments
            .firstWhere((r) => r.source == 'invoice')
            .selectionAutomatic,
        false,
      );
      final generate = find.byKey(
        const ValueKey('generate-projected-payments'),
      );
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pumpAndSettle();
      expect(
        repo.saved[f.incomeWeek]!.payments
            .firstWhere((r) => r.source == 'invoice')
            .included,
        false,
      );
      expect(
        find.textContaining('Se conservaron 1 exclusiones o borrados'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'deleted proposal survives normal generation and can explicitly restore included payments',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = fixtures.MemoryProjectionRepository();
      final rows = paymentProposal(
        await repo.proposal(f.incomeWeek, f.incomeWeek),
      );
      final manual = payment(
        'manual:keep',
        source: 'manual',
        automatic: false,
        amount: 12345,
        included: false,
        notes: 'Conservar captura',
      );
      repo.saved[f.incomeWeek] = WeeklyExpensePlan(
        week: f.incomeWeek,
        generated: true,
        openingCash: 15000,
        openingFiscal: 35000,
        menudeo: const MenudeoExpenseSettings(purchases: 100, expenses: 200),
        payments: [...rows, manual],
      );
      final otherWeek = f.incomeWeek.add(const Duration(days: 7));
      final otherPlan = WeeklyExpensePlan(week: otherWeek, openingCash: 999);
      repo.saved[otherWeek] = otherPlan;
      await tester.pumpWidget(
        income.app(
          WeeklyProjectionView(
            bundle: f.incomeBundle(),
            repository: repo,
            incomeRepository: income.MemoryIncomeRepository(),
            flow: false,
            active: true,
            clock: () => f.incomeWeek,
            onWeekChanged: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final row in rows.where((r) => r.included)) {
        final remove = find.byKey(ValueKey('delete-payment-${row.id}'));
        await tester.ensureVisible(remove);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Borrar egreso'));
        await tester.pumpAndSettle();
      }
      final generate = find.byKey(
        const ValueKey('generate-projected-payments'),
      );
      await tester.ensureVisible(generate);
      for (var i = 0; i < 3; i++) {
        await tester.tap(generate);
        await tester.pumpAndSettle();
        expect(repo.saved[f.incomeWeek]!.total, 0);
      }
      // New source information must be used at reset, not the earlier snapshot.
      repo.invoices = [
        finance.invoice('invoice-1', 10000, '2026-09-24', balance: 8000),
        finance.invoice('fresh', 300, '2026-09-24', provider: 'NEW'),
        finance.invoice('future', 900, '2026-10-01', provider: 'FUTURE'),
      ];
      final restore = find.byKey(const ValueKey('reset-projected-payments'));
      await tester.ensureVisible(restore);
      final writesBefore = repo.writes;
      await tester.tap(restore);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('3 pagos incluidos por \$10,800.00'),
        findsOneWidget,
      );
      expect(
        find.textContaining('egresos manuales, saldos iniciales'),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repo.writes, writesBefore);
      expect(repo.saved[f.incomeWeek]!.total, 0);
      // A failed write must leave removals intact and allow retry.
      repo.failSave = true;
      await tester.tap(restore);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restablecer propuesta'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo guardar'), findsOneWidget);
      expect(repo.writes, writesBefore);
      expect(repo.saved[f.incomeWeek]!.total, 0);
      repo.failSave = false;
      await tester.tap(restore);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final saved = repo.saved[f.incomeWeek]!;
      expect(saved.payments.length, 5);
      expect(saved.payments.where((r) => r.included).length, 3);
      expect(saved.payments.any((r) => r.removed), false);
      expect(saved.total, 1080000);
      expect(
        saved.payments.singleWhere((r) => r.id == 'invoice:future').total,
        0,
      );
      expect(
        saved.payments.singleWhere((r) => r.id == manual.id).toJson(),
        manual.toJson(),
      );
      expect(saved.openingCash, 15000);
      expect(saved.openingFiscal, 35000);
      expect(saved.menudeo.purchases, 100);
      expect(saved.menudeo.expenses, 200);
      expect(identical(repo.saved[otherWeek], otherPlan), true);
      expect(
        find.textContaining(
          'Propuesta de Finanzas restablecida · 3 pagos incluidos',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('edit-payment-invoice:invoice-1')),
        findsOneWidget,
      );
      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pumpAndSettle();
      expect(repo.saved[f.incomeWeek]!.total, 1080000);
      expect(repo.saved[f.incomeWeek]!.payments.length, 5);
      await tester.binding.setSurfaceSize(const Size(780, 1000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
