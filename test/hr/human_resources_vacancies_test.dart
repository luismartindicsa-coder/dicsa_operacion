import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/hr/human_resources_area_chrome.dart';
import 'package:dicsa_operacion/app/hr/human_resources_theme.dart';
import 'package:dicsa_operacion/app/hr/vacancies/hr_staffing.dart';
import 'package:dicsa_operacion/app/hr/vacancies/hr_staffing_editor.dart';
import 'package:dicsa_operacion/app/hr/vacancies/hr_staffing_workspace.dart';
import 'package:dicsa_operacion/app/hr/vacancies/hr_vacancy_alerts.dart';
import 'package:dicsa_operacion/app/shared/app_shell.dart';
import 'package:dicsa_operacion/app/shared/dicsa_logo_mark.dart';
import 'package:dicsa_operacion/app/shared/ui_contract_core/theme/area_theme_scope.dart';

const preview = bool.fromEnvironment('HR_VACANCIES_PREVIEW');
HrStaffingTarget target(
  String id, {
  String company = 'DICSA CELAYA',
  String position = 'AUXILIAR DE PISO',
  int required = 10,
  int filled = 8,
}) => HrStaffingTarget({
  'id': id,
  'company': company,
  'position': position,
  'required_count': required,
  'filled_count': filled,
  'revision': 3,
});
HrStaffingSnapshot snapshot([List<HrStaffingTarget>? rows]) =>
    HrStaffingSnapshot(
      targets:
          rows ??
          [
            target('a'),
            target(
              'b',
              company: 'KS',
              position: 'OPERADOR',
              required: 3,
              filled: 3,
            ),
            target(
              'c',
              company: 'MONROE',
              position: 'TÉCNICO',
              required: 2,
              filled: 1,
            ),
          ],
      companies: ['DICSA CELAYA', 'KS', 'MONROE'],
      unassignedCount: 2,
    );
Future<void> app(
  WidgetTester tester,
  Widget child, {
  double width = 1440,
  double height = 950,
  bool shell = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (preview) {
    await tester.runAsync(() async {
      for (final font in {
        'Roboto': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(font.key)..addFont(
              File(
                '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/${font.value}',
              ).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      }
    });
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: preview ? 'Roboto' : null),
      home: AreaThemeScope(
        tokens: humanResourcesAreaTokens,
        child: shell
            ? AppShell(
                background: const HumanResourcesAreaBackground(),
                animateHeaderSlots: false,
                animateBody: false,
                wrapBodyInGlass: false,
                headerCenterSidePadding: 220,
                leadingBuilder: (_, _) => HumanResourcesAreaHeaderButton(
                  label: 'Navegación',
                  icon: Icons.menu,
                  onTap: () async {},
                ),
                centerBuilder: (_, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const DicsaLogoD(size: 54),
                    const SizedBox(width: 12),
                    Text(
                      'Vacantes RH',
                      style: TextStyle(
                        color: humanResourcesAreaTokens.onGlass,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                trailingBuilder: (_, _) => HumanResourcesAreaHeaderButton(
                  label: 'Cerrar sesión',
                  icon: Icons.logout,
                  onTap: () async {},
                ),
                child: child,
              )
            : Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> capture(
  WidgetTester tester,
  String name, {
  double width = 1440,
  double height = 950,
}) async {
  if (!preview) return;
  await tester.runAsync(() async {
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    final image = await layer.toImage(Rect.fromLTWH(0, 0, width, height));
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '/private/tmp/dicsa_hr_vacancies/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> openEditor(
  WidgetTester tester, {
  List<HrStaffingTarget> targets = const [],
  required Future<void> Function(List<HrStaffingSave>) save,
}) async {
  await app(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () => showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AreaThemeScope(
            tokens: humanResourcesAreaTokens,
            child: HrStaffingEditor(
              targets: targets,
              companies: snapshot().companies,
              loadPositions: () async => ['AUXILIAR DE PISO', 'OPERADOR'],
              createPosition: (s) async => s,
              onSave: save,
            ),
          ),
        ),
        child: const Text('Abrir'),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'snapshot shows current shortages, never negative and adds reusable company options',
    () {
      final s = HrStaffingSnapshot.fromJson({
        'targets': [
          target('a').row,
          target('b', filled: 12).row,
          target('c', required: 0, filled: 2).row,
        ],
        'companies': ['dicsa celaya', ' KS '],
        'unassigned_count': 2,
      });
      expect(s.vacancyCount, 2);
      expect(s.pending.map((t) => t.id), ['a']);
      expect(s.companies.where((c) => c == 'KS'), hasLength(1));
      expect(s.unassignedCount, 2);
    },
  );
  testWidgets(
    'new target picks company and existing job with one click then saves total',
    (tester) async {
      List<HrStaffingSave>? saved;
      await openEditor(tester, save: (ops) async => saved = ops);
      await tester.tap(find.byKey(const ValueKey('staffingCompany')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byType(TextField).last)
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.tap(find.text('DICSA CELAYA'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('staffingPosition')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AUXILIAR DE PISO'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('staffingCount')), '10');
      await tester.pump();
      await capture(tester, 'new-target');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(saved!.single.company, 'DICSA CELAYA');
      expect(saved!.single.position, 'AUXILIAR DE PISO');
      expect(saved!.single.requiredCount, 10);
      expect(saved!.single.revision, 0);
      expect(find.byType(HrStaffingEditor), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('new target can add a reusable job and blocks missing fields', (
    tester,
  ) async {
    List<HrStaffingSave>? saved;
    await openEditor(tester, save: (ops) async => saved = ops);
    await tester.tap(find.text('Guardar plantilla'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.textContaining('Selecciona empresa y puesto'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('staffingCompany')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('KS'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('staffingPosition')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('jobPositionSearch')),
      'jefe de piso',
    );
    await tester.pump();
    await tester.tap(find.text('Agregar «JEFE DE PISO»'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('staffingCount')), '4');
    await tester.tap(find.text('Guardar plantilla'));
    await tester.pumpAndSettle();
    expect(saved!.single.position, 'JEFE DE PISO');
    expect(saved!.single.requiredCount, 4);
  });
  testWidgets(
    'multi-edit retains identities/revisions, accepts zero, Escape cancels without saving',
    (tester) async {
      List<HrStaffingSave>? saved;
      await openEditor(
        tester,
        targets: snapshot().targets.take(2).toList(),
        save: (ops) async => saved = ops,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('staffingCount')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.enterText(find.byKey(const ValueKey('staffingCount')), '0');
      await tester.tap(find.text('Guardar plantilla'));
      await tester.pumpAndSettle();
      expect(saved!.map((op) => op.id), ['a', 'b']);
      expect(
        saved!.every((op) => op.requiredCount == 0 && op.revision == 3),
        isTrue,
      );
      saved = null;
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(saved, isNull);
    },
  );
  testWidgets(
    'uncertain save freezes fields and retries the identical request once',
    (tester) async {
      final attempts = <List<HrStaffingSave>>[];
      final wait = Completer<void>();
      await openEditor(
        tester,
        targets: [target('a')],
        save: (ops) async {
          attempts.add(ops);
          if (attempts.length == 1) {
            ops.single.confirmationPending = true;
            throw StateError('lost reply');
          }
          await wait.future;
        },
      );
      await tester.enterText(find.byKey(const ValueKey('staffingCount')), '12');
      await tester.tap(find.text('Guardar plantilla'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('staffingCount')))
            .enabled,
        isFalse,
      );
      await tester.tap(find.text('Reintentar guardado'));
      await tester.pump();
      await tester.tap(find.text('Guardando…'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(attempts, hasLength(2));
      expect(identical(attempts[0], attempts[1]), isTrue);
      expect(find.byType(HrStaffingEditor), findsOneWidget);
      wait.complete();
      await tester.pumpAndSettle();
      expect(find.byType(HrStaffingEditor), findsNothing);
    },
  );
  testWidgets(
    'pending button opens fresh alerts, updates after termination, then removes covered shortages',
    (tester) async {
      var current = snapshot();
      await app(tester, HrVacancyPendingButton(load: () async => current));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('vacancyBadge'))).data,
        '3',
      );
      current = snapshot([target('a', filled: 7)]);
      await tester.tap(find.text('Pendientes'));
      await tester.pumpAndSettle();
      expect(find.text('Faltan 3'), findsOneWidget);
      expect(find.text('7 activos de 10 requeridos'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('vacancyAlertSearch')),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      await capture(tester, 'alerts');
      current = snapshot([target('a', filled: 10)]);
      hrStaffingChanges.changed();
      await tester.pumpAndSettle();
      expect(find.text('Faltan 3'), findsNothing);
      expect(find.text('La plantilla está cubierta.'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(HrVacancyAlertsDialog), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('vacancyBadge'))).data,
        '0',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'failed refresh is visible rather than presenting zero as no vacancies',
    (tester) async {
      await app(
        tester,
        HrVacancyPendingButton(load: () async => throw StateError('offline')),
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('vacancyBadge'))).data,
        '!',
      );
      await tester.tap(find.text('Pendientes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudieron actualizar'), findsOneWidget);
      expect(find.text('La plantilla está cubierta.'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('local changes during an in-flight alert request are reloaded', (
    tester,
  ) async {
    final response = Completer<HrStaffingSnapshot>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AreaThemeScope(
          tokens: humanResourcesAreaTokens,
          child: Scaffold(
            body: HrVacancyPendingButton(
              load: () {
                calls++;
                return calls == 1
                    ? response.future
                    : Future.value(snapshot([target('a', filled: 6)]));
              },
            ),
          ),
        ),
      ),
    );
    hrStaffingChanges.changed();
    response.complete(snapshot());
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('vacancyBadge'))).data,
      '4',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [900.0, 1440.0]) {
    testWidgets(
      'real workspace fits $width with shared filters, actions and keyboard',
      (tester) async {
        List<HrStaffingTarget>? edited;
        await app(
          tester,
          HrStaffingWorkspace(
            snapshot: snapshot(),
            onEdit: (rows) async => edited = rows,
            pendingButton: HrVacancyPendingButton(load: () async => snapshot()),
          ),
          width: width,
          shell: true,
        );
        expect(tester.takeException(), isNull);
        await capture(tester, 'vacancies-${width.toInt()}', width: width);
        await tester.tap(find.byKey(const ValueKey('staffing-edit-a')));
        await tester.pumpAndSettle();
        expect(edited!.single.id, 'a');
        await tester.enterText(
          find.byKey(const ValueKey('staffingSearch')),
          'tecnico',
        );
        await tester.pumpAndSettle();
        expect(find.text('MONROE'), findsOneWidget);
        expect(find.text('DICSA CELAYA'), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('staffingSearch')),
          '',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Solo por cubrir'));
        await tester.pumpAndSettle();
        expect(find.text('KS'), findsNothing);
        expect(find.text('MONROE'), findsOneWidget);
        await tester.tap(find.byTooltip('Filtrar EMPRESA'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('DICSA CELAYA').last);
        await tester.tap(find.text('Aplicar'));
        await tester.pumpAndSettle();
        expect(find.text('DICSA CELAYA'), findsOneWidget);
        expect(find.text('MONROE'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('Ctrl selection and right-click preserve rows for a multi-edit', (
    tester,
  ) async {
    List<HrStaffingTarget>? edited;
    await app(
      tester,
      HrStaffingWorkspace(
        snapshot: snapshot(),
        onEdit: (rows) async => edited = rows,
        pendingButton: const SizedBox.shrink(),
      ),
    );
    await tester.tap(find.text('DICSA CELAYA'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('KS'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Editar 2 seleccionadas'), findsOneWidget);
    await tester.tap(find.text('KS'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar plantillas seleccionadas'));
    await tester.pumpAndSettle();
    expect(edited!.map((r) => r.id), ['a', 'b']);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Editar 2 seleccionadas'), findsNothing);
  });
  testWidgets(
    'keyboard scroll reveals offscreen targets and Enter edits the active row',
    (tester) async {
      List<HrStaffingTarget>? edited;
      await app(
        tester,
        HrStaffingWorkspace(
          snapshot: snapshot(
            List.generate(40, (i) => target('row-$i', position: 'PUESTO $i')),
          ),
          onEdit: (rows) async => edited = rows,
          pendingButton: const SizedBox.shrink(),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(edited!.single.id, 'row-29');
      expect(find.text('PUESTO 29').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Vacantes navigation is available in RH without adding Dirección access',
    () {
      Future<void> noop() async {}
      final sections = buildHumanResourcesAreaSections(
        activeScreen: HumanResourcesAreaScreen.vacancies,
        openPersonnel: noop,
        openAttendance: noop,
        openImportConciliation: noop,
        openVacations: noop,
        openPermissions: noop,
        openPrenomina: noop,
        openNomina: noop,
        openTerminations: noop,
        openLoans: noop,
        openDocumentation: noop,
        openVacancies: noop,
      );
      final entry = sections
          .expand((s) => s.items)
          .singleWhere((e) => e.title == 'Vacantes');
      expect(entry.accented, isTrue);
      expect(entry.onTap, isNull);
      final access = buildHumanResourcesAccessItems(
        activeScreen: HumanResourcesAreaScreen.vacancies,
        openDashboard: noop,
        canReturnToDirection: false,
        openDirectionDashboard: noop,
      );
      expect(access.any((e) => e.title.contains('Dirección')), isFalse);
    },
  );
}
