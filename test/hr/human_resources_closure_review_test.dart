import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/hr/human_resources_loans.dart';
import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const period = 'Periodo 37 semanal · 04/09/2026 - 10/09/2026';
final employees = [
  for (final entry in [
    ('1', 'ANA PRUEBA'),
    ('2', 'BETO PRUEBA'),
    ('3', 'CARLA PRUEBA'),
    ('4', 'DIEGO PRUEBA'),
  ])
    {
      'id': entry.$1,
      'nombre': entry.$2,
      'empresa': entry.$1 == '1' ? 'KS' : 'DICSA',
      'salario': 2205.28,
      'salario_flujo': 1000,
      'employment_status': 'activo',
    },
];
HrLoanPayrollPlan plan(int cents) => HrLoanPayrollPlan(
  end: DateTime(2026, 9, 10),
  fiscalReady: true,
  dues: [HrLoanAllocation('loan-1', 7, cents)],
  allocations: [HrLoanAllocation('loan-1', 7, cents)],
);
final fund = HrLoanFundState(
  capitalCents: 1500000,
  loans: [
    HrLoan.fromRow({
      'id': 'loan-1',
      'folio': 7,
      'employee_id': '1',
      'employee_name': 'ANA PRUEBA',
      'principal': 1200,
      'installment_count': 4,
      'repayment_method': 'nomina',
      'payroll_channel': 'flujo',
      'frequency': 'semanal',
      'issued_on': '2026-09-01',
      'first_due_on': '2026-09-04',
    }),
  ],
  payments: [],
);
final drafts = [
  for (final id in ['1', '2', '3'])
    {
      'id': 'draft-$id',
      'employee_id': id,
      'period_label': period,
      'draft_status': id == '3' ? 'publicado' : 'listo',
      'fiscal_net_amount': 1800,
      'cash_salary_amount': 1000,
      'cash_salary_is_manual': true,
      'loan_deduction_amount': id == '1' ? 200 : 0,
      'source_snapshot': {
        'contpaq_official_net': 1800,
        'incidences_informational': true,
        if (id == '1') 'loan_fund': plan(20000).toJson(),
      },
    },
];
final attendance = [
  {
    'employee_id': '2',
    'period_label': period,
    'source_date': '04/09/2026',
    'status': 'sin_horario',
    'source_mode': 'manual',
  },
];

void main() {
  setUpAll(() async {
    if (Platform.environment['HR_CLOSURE_PREVIEW_DIR'] == null) return;
    const fonts =
        '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts';
    for (final pair in [
      ('Ahem', 'Roboto-Regular.ttf'),
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(pair.$1)..addFont(
            File('$fonts/${pair.$2}').readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
  });
  var snapshot = <String, dynamic>{};
  final actions = <String>[];
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1450, 1000),
    String? loanError,
    List<Map<String, dynamic>>? savedDrafts,
    HrLoanFundState? loanFund,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    actions.clear();
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => RepaintBoundary(
          key: const ValueKey('closure-preview'),
          child: child!,
        ),
        home: hrPrenominaGridForTesting(
          period: period,
          employees: employees,
          drafts: savedDrafts ?? drafts,
          attendance: attendance,
          permissions: [
            {
              'id': 'permission-4',
              'employee_id': '4',
              'attendance_period_label': period,
              'start_date': '2026-09-04',
              'end_date': '2026-09-04',
              'status': 'aprobado',
              'permission_type': 'permiso_sin_goce',
              'request_unit': 'dia',
              'quantity_days': 1,
              'impact_prenomina': true,
              'prenomina_sync_status': 'pendiente',
            },
          ],
          loanFund: loanFund ?? fund,
          loanLoadError: loanError,
          useClosureReview: true,
          onSnapshot: (value) => snapshot = value,
          onAction: actions.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Cerrar periodo'));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final directory = Platform.environment['HR_CLOSURE_PREVIEW_DIR'];
    if (directory == null) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('closure-preview')),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'closure lists all blockers, opens hidden employee and updates after saving',
    (tester) async {
      await mount(tester);
      await tester.enterText(
        find.byKey(const ValueKey('employee-search')),
        'BETO',
      );
      await tester.pumpAndSettle();
      expect(snapshot['visible_ids'], ['2']);
      await open(tester);
      expect(find.text('Pendientes para cerrar'), findsOneWidget);
      expect(find.text('Préstamos por actualizar (1)'), findsOneWidget);
      expect(find.text('Por publicar (3)'), findsOneWidget);
      expect(find.text(r'$200.00'), findsWidgets);
      expect(find.text(r'$300.00'), findsWidgets);
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('closure-search')),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.focusNode.hasFocus, isTrue);
      await capture(tester, 'closure-desktop');
      await tester.ensureVisible(
        find.byKey(const ValueKey('closure-review-1')),
      );
      await tester.tap(find.byKey(const ValueKey('closure-review-1')));
      await tester.pumpAndSettle();
      expect(find.text('ANA PRUEBA'), findsOneWidget);
      expect(find.text('Descuento fiscal manual'), findsOneWidget);
      expect(actions.where((a) => a.startsWith('save:')), isEmpty);
      await tester.tap(find.text('Guardar borrador'));
      await tester.pumpAndSettle();
      expect(find.text('Préstamos por actualizar (0)'), findsOneWidget);
      expect(find.text('Por publicar (3)'), findsOneWidget);
      expect(snapshot['visible_ids'], ['2']); // Main filter survives review.
      expect(actions, contains('save:1:save'));

      await tester.enterText(
        find.byKey(const ValueKey('closure-search')),
        'ANA',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('closure-review-1')),
      );
      await tester.tap(find.byKey(const ValueKey('closure-review-1')));
      await tester.pumpAndSettle();
      expect(find.text('Administración del borrador'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('picker-Estatus')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publicado').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar y publicar'));
      await tester.pumpAndSettle();
      expect(find.text('Por publicar (2)'), findsOneWidget);
      expect(find.byKey(const ValueKey('closure-employee-1')), findsNothing);
      expect(actions.where((a) => a.startsWith('save:')), hasLength(2));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('closure-review-dialog')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact review filters loans and explains attendance without overflow',
    (tester) async {
      await mount(tester, size: const Size(1000, 760));
      await tester.enterText(
        find.byKey(const ValueKey('employee-search')),
        'SIN RESULTADOS',
      );
      await tester.pumpAndSettle();
      expect(snapshot['count'], 0);
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('closure-filter-prestamos')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('closure-employee-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('closure-employee-2')), findsNothing);
      await capture(tester, 'closure-compact');
      await tester.tap(find.byKey(const ValueKey('closure-filter-publicar')));
      await tester.enterText(
        find.byKey(const ValueKey('closure-search')),
        'BETO',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Asistencia: 1 día(s)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('closure-review-2')));
      await tester.pumpAndSettle();
      expect(find.text('BETO PRUEBA'), findsWidgets);
      expect(find.text('Administración del borrador'), findsNothing);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('closure-search')),
        'DIEGO',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Permisos: 1 movimiento(s)'), findsOneWidget);
      expect(find.text('Revisar Vacaciones y permisos'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(actions.where((a) => a.startsWith('save:')), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unavailable loans explain recovery and do not allow saving', (
    tester,
  ) async {
    const error =
        'No se pudieron consultar los préstamos. Vuelve a abrir Prenómina antes de guardar o cerrar.';
    await mount(tester, loanError: error);
    await open(tester);
    expect(find.text(error), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('closure-review-1')))
          .onPressed,
      isNull,
    );
    expect(find.text('Cerrar periodo de nómina'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a removed allocation is still flagged until the draft is saved',
    (tester) async {
      await mount(
        tester,
        loanFund: const HrLoanFundState(
          capitalCents: 1500000,
          loans: [],
          payments: [],
        ),
      );
      await open(tester);
      expect(find.text('Préstamos por actualizar (1)'), findsOneWidget);
      expect(find.text(r'$200.00'), findsWidgets);
      expect(find.text('Actual: sin cuotas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all published with matching loans keeps the final confirmation',
    (tester) async {
      final saved = [
        for (final employee in employees)
          {
            'id': 'saved-${employee['id']}',
            'employee_id': employee['id'],
            'period_label': period,
            'draft_status': 'publicado',
            'fiscal_net_amount': 1800,
            'cash_salary_amount': 1000,
            'source_snapshot': {
              'incidences_informational': true,
              'contpaq_official_net': 1800,
              if (employee['id'] == '1') 'loan_fund': plan(30000).toJson(),
            },
          },
      ];
      await mount(tester, savedDrafts: saved);
      await open(tester);
      expect(find.byKey(const ValueKey('closure-review-dialog')), findsNothing);
      expect(find.text('Cerrar periodo de nómina'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(actions, ['close']);
      expect(tester.takeException(), isNull);
    },
  );
}
