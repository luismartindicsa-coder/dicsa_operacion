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
  setUpAll(() async {
    if (Platform.environment['HR_TERMINATION_PREVIEW'] == '1') {
      for (final family in ['Ahem', 'Roboto']) {
        final loader = FontLoader(family)
          ..addFont(
            File(
              '/opt/homebrew/share/flutter/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf',
            ).readAsBytes().then((b) => ByteData.sublistView(b)),
          );
        await loader.load();
      }
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await icons.load();
    }
  });
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(1200, 900),
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
    if (Platform.environment['HR_TERMINATION_PREVIEW'] == '1') {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/private/tmp/hr_termination_preview.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
    expect(tester.takeException(), isNull);
  });
}
