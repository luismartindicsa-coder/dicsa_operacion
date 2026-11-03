import 'package:dicsa_operacion/app/contabilidad/contabilidad_theme.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_engine.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_models.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_repository.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_review_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingRepository extends StatementRepository {
  StatementDecision? saved;
  StatementClosing? closing;
  bool fail = false;
  @override
  Future<void> saveDecision(StatementDecision d) async {
    d.validate();
    if (fail) {
      throw StateError('Cambió en otra sesión');
    }
    saved = d;
  }

  @override
  Future<void> saveClosing(StatementPeriod p, StatementClosing c) async {
    closing = c;
  }
}

void main() {
  final period = StatementPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
  StatementAnalysis analysis() => analyzeStatement(
    StatementBundle(
      period: period,
      canManage: true,
      tables: {
        'finanzas_bank_movements': [
          {
            'id': 'bank',
            'movement_date': '2026-10-01',
            'debit_amount': 500,
            'credit_amount': 0,
            'counterparty_name_snapshot': 'Renta',
          },
        ],
      },
    ),
  );
  Future<void> mount(
    WidgetTester tester,
    RecordingRepository repository,
    List<bool> editing,
    VoidCallback saved, {
    StatementAnalysis? value,
    bool onlyPending = true,
  }) async {
    tester.view.physicalSize = const Size(1100, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatementReviewPanel(
              analysis: value ?? analysis(),
              onlyPending: onlyPending,
              onSaved: () async => saved(),
              onEditing: editing.add,
              repository: repository,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);
  testWidgets(
    'filter and editor dropdowns keep readable contrast over a light app theme',
    (tester) async {
      final repository = RecordingRepository();
      await mount(tester, repository, [], () {});

      void expectReadableMenu(String option) {
        final context = tester.element(find.text(option).last);
        final background = Theme.of(context).canvasColor;
        final foreground = DefaultTextStyle.of(context).style.color!;
        expect(background, kContabilidadBgTeal);
        final contrast =
            (foreground.computeLuminance() + 0.05) /
            (background.computeLuminance() + 0.05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      }

      await tester.tap(find.text('Todas las fuentes'));
      await tester.pumpAndSettle();
      expectReadableMenu('Bancos');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Revisar operación'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<StatementAccount>));
      await tester.pumpAndSettle();
      expectReadableMenu(StatementAccount.operating.label);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repository.saved, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'topics filter real pending rows and included estimates remain explicit',
    (tester) async {
      final a = analyzeStatement(
        StatementBundle(
          period: period,
          canManage: true,
          tables: {
            'men_cash_vouchers': [
              {
                'id': 'f',
                'voucher_type': 'expense',
                'voucher_date': '2026-10-01',
                'rubric': 'Nomina',
                'comment': 'FINIQUITO',
                'total_amount': 1000,
                'folio': '1',
                'person_label': 'JUAN',
              },
            ],
            'men_cash_voucher_lines': [
              {
                'id': 'l',
                'voucher_id': 'f',
                'concept': 'Empresa',
                'amount': 1000,
              },
            ],
            'finanzas_bank_movements': [
              {
                'id': 'tax',
                'movement_date': '2026-10-01',
                'debit_amount': 50,
                'category': 'IMPUESTOS',
                'reference': 'ISR',
                'counterparty_name_snapshot': 'SAT',
              },
            ],
          },
        ),
      );
      await mount(tester, RecordingRepository(), [], () {}, value: a);
      expect(find.text('Vale 1 · JUAN'), findsNothing);
      expect(find.text('SAT · ISR'), findsNothing);
      expect(
        find.textContaining('1 ya incluidos en el contable'),
        findsOneWidget,
      );
      await tester.tap(find.text('Datos por completar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya incluidos en el contable').last);
      await tester.pumpAndSettle();
      expect(find.text('Vale 1 · JUAN'), findsOneWidget);
      expect(
        find.textContaining('Incluido provisional · pendiente de revisión'),
        findsOneWidget,
      );
      await tester.tap(find.text('Ya incluidos en el contable').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revisiones de cierre').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todos los temas'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Impuestos y retenciones · 1 documentos').last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Vale 1 · JUAN'), findsNothing);
      expect(find.text('SAT · ISR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'estimates already included are separated from pending operations',
    (tester) async {
      final a = analyzeStatement(
        StatementBundle(
          period: period,
          canManage: true,
          tables: {
            'finanzas_supplier_invoices': [
              {
                'id': 'power',
                'invoice_date': '2026-10-05',
                'invoice_folio': 'CFE-1',
                'provider_name_snapshot': 'CFE',
                'total_amount': 116,
              },
            ],
          },
        ),
      );
      await mount(tester, RecordingRepository(), [], () {}, value: a);
      expect(find.text('Factura CFE-1 · CFE'), findsNothing);
      await tester.tap(find.text('Datos por completar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todas las estimaciones').last);
      await tester.pumpAndSettle();
      expect(find.text('Factura CFE-1 · CFE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'automatic entries are explained, editable, and excluded from pending',
    (tester) async {
      final a = analyzeStatement(
        StatementBundle(
          period: period,
          canManage: true,
          tables: {
            'pesadas': [
              {
                'id': 'w',
                'ticket': '542',
                'fecha': '2026-10-01',
                'precio': 80,
                'proveedor': 'PUBLICO',
              },
            ],
          },
        ),
      );
      final repository = RecordingRepository(), editing = <bool>[];
      await mount(
        tester,
        repository,
        editing,
        () {},
        value: a,
        onlyPending: false,
      );
      expect(
        find.textContaining('Otro ingreso real · automático'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Revisar operación'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Servicio de Pesadas reconocido por su precio'),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await mount(tester, repository, editing, () {}, value: a);
      expect(find.text('No hay operaciones en este filtro.'), findsOneWidget);
      expect(find.byTooltip('Revisar operación'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'review validates, preserves input on conflict, saves and releases refresh deferral',
    (tester) async {
      final repository = RecordingRepository(), editing = <bool>[];
      var saves = 0;
      await mount(tester, repository, editing, () => saves++);
      await tester.tap(find.byTooltip('Revisar operación'));
      await tester.pumpAndSettle();
      expect(editing, [true]);
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(repository.saved, isNull);
      expect(
        find.textContaining('Completa importe y fundamento'),
        findsOneWidget,
      );
      await tester.tap(find.byType(DropdownButtonFormField<StatementAccount>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(StatementAccount.operating.label).last);
      await tester.pumpAndSettle();
      final note = field('Fundamento y comprobantes de la clasificación');
      await tester.ensureVisible(note);
      await tester.tap(note);
      await tester.enterText(note, 'Renta devengada; base sin IVA verificada');
      repository.fail = true;
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cambió en otra sesión'), findsOneWidget);
      expect(
        find.text('Renta devengada; base sin IVA verificada'),
        findsOneWidget,
      );
      repository.fail = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(repository.saved!.account, StatementAccount.operating);
      expect(repository.saved!.amount, 500);
      expect(saves, 1);
      expect(editing, [true, false]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Escape closes editors and incomplete closing only saves progress',
    (tester) async {
      final repository = RecordingRepository(), editing = <bool>[];
      await mount(tester, repository, editing, () {});
      await tester.tap(find.text('Vincular efectivo'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.hasAnyClients, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(editing, [true, false]);
      await tester.tap(find.text('Revisar cierre'));
      await tester.pumpAndSettle();
      final note = field('Responsable, alcance y evidencia del cierre');
      await tester.ensureVisible(note);
      await tester.enterText(note, 'Avance de conciliación');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(repository.closing!.signature, isEmpty);
      expect(repository.closing!.snapshot, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
