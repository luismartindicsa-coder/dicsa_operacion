import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/hr/human_resources_terminations_page.dart';
import 'package:dicsa_operacion/app/hr/human_resources_termination_calculation.dart';
import 'package:dicsa_operacion/app/hr/human_resources_theme.dart';
import 'package:dicsa_operacion/app/shared/ui_contract_core/theme/area_theme_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'human_resources_termination_calculation_test.dart' show fixture;

const employee = <String, dynamic>{
  'id': 'demo',
  'nombre': 'COLABORADOR DE PRUEBA',
  'empresa': 'DICSA',
  'fecha_ingreso': '2020-07-30',
  'termination_date': '2026-09-04',
  'salario': 2205.2,
  'salario_flujo': 0,
  'fiscal_payment_mode': 'deposito',
};

void main() {
  final preview =
      const bool.fromEnvironment('HR_TERMINATION_PREVIEW') ||
      Platform.environment['HR_TERMINATION_PREVIEW'] == '1';
  setUpAll(() async {
    if (preview) {
      for (final family in ['Ahem', 'Roboto']) {
        final loader = FontLoader(family)
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
        await loader.load();
      }
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });

  Future<void> capture(WidgetTester tester, String name) async {
    if (!preview) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/private/tmp/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1200, 900),
    TargetPlatform? platform,
    Map<String, dynamic>? inputs,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)? save,
    ValueChanged<bool>? dirty,
    ValueChanged<bool>? busy,
    Future<List<Map<String, dynamic>>> Function()? history,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          platform: platform,
          textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto'),
        ),
        home: Scaffold(
          backgroundColor: const Color(0xFF1B102B),
          body: AreaThemeScope(
            tokens: humanResourcesAreaTokens,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: RepaintBoundary(
                key: const ValueKey('capture'),
                child: HrTerminationEditor(
                  employee: employee,
                  antecedents: const {
                    'events': [],
                    'vacation_payments': [],
                    'payrolls': [],
                  },
                  initialInputs: inputs ?? fixture(),
                  onDirty: dirty ?? (_) {},
                  onBusy: busy,
                  onSave:
                      save ??
                      (record) async => {
                        ...record,
                        'id': 'demo-record',
                        'revision': 1,
                      },
                  onHistory: history ?? () async => [],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'all tabs fit the minimum desktop width without rendering errors',
    (tester) async {
      await mount(tester, size: const Size(900, 760));
      for (final tab in [
        'Datos',
        'Prestaciones y ajustes',
        'Antecedentes',
        'Resultado',
      ]) {
        await tester.tap(find.widgetWithText(ChoiceChip, tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
    },
  );

  testWidgets(
    'typing, deleting and recalculation preserve field text and flow',
    (tester) async {
      await mount(tester, inputs: {...fixture(), 'weekly_flow': 1000});
      final flow = find.byKey(const ValueKey('termination_weekly_flow'));
      await tester.ensureVisible(flow);
      await tester.enterText(flow, '1200');
      await tester.pump();
      expect(tester.widget<TextField>(flow).controller!.text, '1200');
      await tester.enterText(flow, '');
      await tester.pump();
      expect(tester.widget<TextField>(flow).controller!.text, '');
      await tester.enterText(flow, '0');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ChoiceChip, 'Prestaciones y ajustes'),
      );
      await tester.pumpAndSettle();
      final isr = find.byKey(const ValueKey('termination_official_isr'));
      await tester.scrollUntilVisible(
        isr,
        450,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.enterText(isr, '0');
      await tester.pumpAndSettle();
      expect(find.text(r'$4,039.27'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saves separate reviewed versions with exact salary, ISR and source',
    (tester) async {
      final records = <Map<String, dynamic>>[];
      final dirties = <bool>[];
      await mount(
        tester,
        dirty: dirties.add,
        save: (record) async {
          records.add(record);
          return {
            ...record,
            'id': 'record-${records.length}',
            'revision': records.length,
          };
        },
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar revisado'));
      await tester.pumpAndSettle();
      expect(records.single['employee_id'], 'demo');
      expect(records.single['status'], 'revisado');
      expect(records.single['inputs']['official_isr'], '125.48');
      expect(records.single['result']['net']['total'], 3913.79);
      expect(records.single['source_snapshot']['personal']['salario'], 2205.2);
      expect(dirties.last, false);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Guardar borrador'));
      await tester.pumpAndSettle();
      expect(records, hasLength(2));
      expect(records.last['status'], 'borrador');
    },
  );

  testWidgets(
    'unknown ISR blocks review but allows an explicitly pending draft',
    (tester) async {
      await mount(tester, inputs: {...fixture(), 'official_isr': ''});
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Guardar revisado'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Guardar borrador'),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.text('Pendiente'), findsNWidgets(3));
    },
  );

  for (final platform in [TargetPlatform.windows, TargetPlatform.macOS]) {
    testWidgets(
      '${platform.name}: completing the visible requirements enables reviewed save',
      (tester) async {
        final records = <Map<String, dynamic>>[];
        await mount(
          tester,
          size: const Size(900, 760),
          platform: platform,
          inputs: {
            ...fixture(),
            'official_isr': '0',
            'isr_reference': '',
            'history_reviewed': false,
          },
          save: (record) async {
            records.add(record);
            return {...record, 'id': 'reviewed-example', 'revision': 1};
          },
        );
        final reviewed = find.widgetWithText(FilledButton, 'Guardar revisado');
        expect(tester.widget<FilledButton>(reviewed).onPressed, isNull);
        await tester.tap(find.text('Ver pendientes (2)'));
        await tester.pumpAndSettle();
        expect(
          find.text('Pendientes para revisión').hitTestable(),
          findsOneWidget,
        );
        expect(
          find.text('• Registrar la referencia del ISR de CONTPAQ.'),
          findsOneWidget,
        );
        expect(
          find.text('• Revisar nóminas y pagos previos de prestaciones.'),
          findsOneWidget,
        );
        expect(records, isEmpty);
        await capture(tester, 'hr_termination_pending_${platform.name}');

        await tester.tap(
          find.widgetWithText(ChoiceChip, 'Prestaciones y ajustes'),
        );
        await tester.pumpAndSettle();
        final reference = find.byKey(
          const ValueKey('termination_isr_reference'),
        );
        await tester.scrollUntilVisible(
          reference,
          400,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .first,
        );
        await tester.enterText(reference, 'CONTPAQ: ISR confirmado en cero');
        await tester.pumpAndSettle();
        expect(find.text('Ver pendientes (1)'), findsOneWidget);
        expect(tester.widget<FilledButton>(reviewed).onPressed, isNull);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Antecedentes'));
        await tester.pumpAndSettle();
        final confirmation = find.byType(CheckboxListTile);
        await tester.scrollUntilVisible(
          confirmation,
          300,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .first,
        );
        await tester.tap(confirmation);
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(reviewed).onPressed, isNotNull);
        expect(find.textContaining('Ver pendientes'), findsNothing);
        await tester.tap(reviewed);
        await tester.pumpAndSettle();
        expect(records.single['status'], 'revisado');
        expect(records.single['inputs']['official_isr'], '0');
        expect(records.single['inputs']['history_reviewed'], true);
        expect(records.single['result']['pending'], isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'permission failure explains access and preserves entered values',
    (tester) async {
      final dirtyStates = <bool>[];
      await mount(
        tester,
        dirty: dirtyStates.add,
        save: (_) async => throw const PostgrestException(
          message: 'new row violates row-level security policy',
          code: '42501',
        ),
      );
      final flow = find.byKey(const ValueKey('termination_weekly_flow'));
      await tester.ensureVisible(flow);
      await tester.enterText(flow, '300');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Guardar borrador'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Tu cuenta no tiene permiso para guardar finiquitos.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('PostgrestException'), findsNothing);
      expect(tester.widget<TextField>(flow).controller!.text, '300');
      expect(dirtyStates.last, true);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Guardar borrador'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'mode switching adds twelve days and requires integration for ninety',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byType(DropdownButton<HrTerminationMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Liquidación').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Finiquito + 12 días por año de servicio.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Resultado'));
      await tester.pumpAndSettle();
      expect(find.text('Liquidación · prima de antigüedad'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<HrTerminationMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Indemnización').last);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Completa el integrado laboral diario Base con un número válido.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed saves keep changes and history opens a new editable copy',
    (tester) async {
      final dirtyStates = <bool>[];
      final busyStates = <bool>[];
      final previousInput = HrTerminationInput({
        ...fixture(),
        'weekly_flow': 500,
      });
      final previous = <String, dynamic>{
        'id': 'old-record',
        'employee_id': 'demo',
        'revision': 2,
        'mode': 'finiquito',
        'status': 'revisado',
        'end_date': '2026-09-04',
        'created_at': '2026-09-09',
        'inputs': previousInput.toJson(),
        'result': HrTerminationResult.calculate(previousInput).toJson(),
      };
      await mount(
        tester,
        dirty: dirtyStates.add,
        busy: busyStates.add,
        history: () async => [previous],
        save: (_) async => throw StateError('Database unavailable'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Guardar borrador'));
      await tester.pumpAndSettle();
      expect(dirtyStates, isNot(contains(false)));
      expect(busyStates, [true, false]);
      expect(find.textContaining('No se guardó el cálculo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Historial'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.widgetWithText(TextButton, 'Abrir copia'));
      await tester.pumpAndSettle();
      final flow = find.byKey(const ValueKey('termination_weekly_flow'));
      expect(tester.widget<TextField>(flow).controller!.text, '500');
      expect(dirtyStates.last, true);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Guardar revisado'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('render sample for visual inspection', (tester) async {
    await mount(tester, inputs: {...fixture(), 'weekly_flow': 2694.72});
    await tester.tap(find.widgetWithText(ChoiceChip, 'Resultado'));
    await tester.pumpAndSettle();
    await capture(tester, 'hr_termination_preview');
    expect(tester.takeException(), isNull);
  });
}
