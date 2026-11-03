import 'package:dicsa_operacion/app/contabilidad/contabilidad_income_statement_store.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_engine.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_models.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_payroll.dart';
import 'package:flutter_test/flutter_test.dart';

final october = StatementPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
StatementRow payroll([String id = 'n']) => {
  'id': id,
  'employee_id': id,
  'empresa': 'DICSA',
  'period_label': 'Periodo 40 · 25/09/2026 - 01/10/2026',
  'draft_status': 'publicado',
  'fiscal_net_amount': 700,
  'cash_salary_amount': 140,
};
StatementAnalysis analyze(
  List<StatementRow> rows, {
  StatementClosing closing = const StatementClosing(),
  Map<String, StatementDecision> decisions = const {},
}) => analyzeStatement(
  StatementBundle(
    period: october,
    tables: {'hr_prenomina_draft_rows': rows},
    closing: closing,
    decisions: decisions,
  ),
);

void main() {
  test(
    'withholdings restore known remuneration; cash deductions and cheque are not extra costs',
    () {
      final r = {
        ...payroll(),
        'check_amount': 700,
        'fiscal_imss_amount': 10,
        'fiscal_infonavit_amount': 30,
        'fiscal_fonacot_amount': 20,
        'cash_isr_amount': 10,
        'cash_infonavit_deduction_amount': 20,
        'cash_fonacot_deduction_amount': 30,
        'loan_deduction_amount': 40,
      };
      expect(statementPayrollRemuneration(r), 900);
      expect(
        analyze([r]).total(StatementAccount.payroll),
        closeTo(900 / 7, .0001),
      );
    },
  );
  test(
    'official net already includes fiscal vacation; manual net does not',
    () {
      final r = {...payroll(), 'fiscal_vacation_amount': 100};
      expect(statementPayrollRemuneration(r), 940);
      r['source_snapshot'] = {'contpaq_official_net': 700};
      expect(statementPayrollRemuneration(r), 840);
    },
  );
  test(
    'cash complements count once, absences follow RH informational flag',
    () {
      final r = {
        ...payroll(),
        'cash_vacation_amount': 30,
        'transport_support_amount': 20,
        'holiday_amount': 10,
        'overtime_monetized_amount': 40,
        'manual_bonus_amount': 20,
        'manual_adjustment_amount': -10,
        'payment_outside_amount': 50,
        'cash_absence_deduction_amount': 50,
        'fiscal_late_deduction_amount': 20,
      };
      expect(statementPayrollRemuneration(r), 930);
      r['source_snapshot'] = {'incidences_informational': true};
      expect(statementPayrollRemuneration(r), 1000);
    },
  );
  test('missing or invalid pay and untraced vacation advances need review', () {
    for (final r in <StatementRow>[
      {},
      {...payroll(), 'cash_salary_amount': 'invalid'},
      {...payroll(), 'fiscal_imss_amount': -1},
      {...payroll(), 'fiscal_manual_deduction_amount': 20},
      {
        ...payroll(),
        'source_snapshot': {
          'prepaid_vacation': {'fiscal': 100},
        },
      },
      {
        ...payroll(),
        'source_snapshot': {
          'prepaid_vacation': {'days': 'invalid'},
        },
      },
      {...payroll(), 'source_snapshot': 'invalid'},
    ]) {
      expect(statementPayrollRemuneration(r), isNull);
    }
    expect(
      statementPayrollRemuneration({
        ...payroll(),
        'source_snapshot': {
          'prepaid_vacation': {'version': 1, 'days': 0, 'fiscal': 0, 'flow': 0},
        },
      }),
      840,
    );
    expect(
      analyze([
        {...payroll(), 'cash_salary_amount': 'invalid'},
      ]).total(StatementAccount.payroll),
      0,
    );
  });
  test(
    'overlapping employee payroll cannot double compensation across companies',
    () {
      final a = analyze([
        payroll(),
        {...payroll('other'), 'employee_id': 'n', 'empresa': 'OTHER'},
      ]);
      expect(a.total(StatementAccount.payroll), 0);
      expect(
        a.pending.where((e) => e.fact.id.startsWith('payroll:')),
        hasLength(2),
      );
      expect(a.warnings, isNotEmpty);
    },
  );
  test('only published periods count and missing days remain explicit', () {
    final a = analyze([
      {...payroll(), 'period_label': '02/10/2026 - 29/10/2026'},
      {
        ...payroll('draft'),
        'draft_status': 'borrador',
        'period_label': '30/10/2026 - 31/10/2026',
      },
    ]);
    expect(a.total(StatementAccount.payroll), 840);
    expect(a.pending.single.fact.label, contains('3 días'));
    expect(
      a.pending.single.fact.detail,
      contains('2026-10-01, 2026-10-30, 2026-10-31'),
    );
    expect(a.entries.where((e) => e.automatic), hasLength(1));
    expect(a.estimated, isTrue);
    expect(a.complete, isFalse);
    for (final period in [
      '31/02/2026 - 06/03/2026',
      '02/10/2026 - 01/10/2026',
      'unknown',
    ]) {
      expect(statementPayrollDates(period), isNull);
    }
  });
  test(
    'manual payroll correction becomes stale when fiscal source changes',
    () {
      final r = payroll();
      final initial = analyze([r]);
      final fact = initial.entries
          .singleWhere((e) => e.fact.id.startsWith('payroll:'))
          .fact;
      final ds = {
        fact.id: StatementDecision(
          id: fact.id,
          signature: fact.signature,
          account: StatementAccount.payroll,
          amount: 150,
          note: 'Bruto revisado',
        ),
      };
      expect(analyze([r], decisions: ds).total(StatementAccount.payroll), 150);
      final changed = analyze([
        {...r, 'fiscal_imss_amount': 10},
      ], decisions: ds);
      expect(changed.total(StatementAccount.payroll), 0);
      expect(
        changed.pending.any(
          (e) => e.issue?.contains('Cambió la fuente') == true,
        ),
        isTrue,
      );
    },
  );
  test(
    'missing bases are displayed as unknown, partial payroll stays visible',
    () {
      final data = statementDatasetFromAnalysis(analyze([payroll()]));
      expect(
        data.lines
            .singleWhere((l) => l.label.startsWith('Costo laboral'))
            .amount,
        -120,
      );
      expect(
        data.lines
            .singleWhere((l) => l.label.startsWith('Costo laboral'))
            .label,
        contains('base parcial'),
      );
      expect(
        data.lines
            .singleWhere((l) => l.label.startsWith('Costo de ventas'))
            .label,
        'Costo de ventas',
      );
      expect(
        data.lines.where((l) => l.amountLabel == 'Por determinar'),
        hasLength(3),
      );
      expect(
        data.warnings.any((s) => s.contains('bruto fiscal completo')),
        isTrue,
      );
    },
  );
  test('documented zero and valid closing remain zero instead of unknown', () {
    final adjustments = <StatementRow>[
      {
        'id': 'zero',
        'date': '2026-10-31',
        'account': 'depreciation',
        'amount': 0,
        'note': 'Sin activos depreciables en la entidad revisada',
      },
    ];
    final a = analyze([], closing: StatementClosing(adjustments: adjustments));
    final data = statementDatasetFromAnalysis(a);
    expect(
      data.lines
          .singleWhere((l) => l.label.startsWith('Depreciación'))
          .amountLabel,
      isNull,
    );
    final closed = analyze(
      [],
      closing: StatementClosing(
        adjustments: adjustments,
        signature: a.signature,
        note: 'Bases completas',
        checks: statementClosingChecks.keys.toSet(),
        snapshot: a.toSnapshot(),
      ),
    );
    expect(closed.complete, isTrue);
    expect(
      statementDatasetFromAnalysis(
        closed,
      ).lines.any((l) => l.amountLabel != null),
      isFalse,
    );
  });
}
