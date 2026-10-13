import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/hr/documentation/hr_document.dart';
import 'package:dicsa_operacion/app/hr/documentation/hr_document_templates.dart';
import 'package:dicsa_operacion/app/hr/documentation/hr_document_pdf.dart';
import 'package:dicsa_operacion/app/hr/documentation/hr_document_repository.dart';
import 'package:dicsa_operacion/app/hr/human_resources_documentation_page.dart';
import 'package:dicsa_operacion/app/hr/human_resources_area_chrome.dart';
import 'package:dicsa_operacion/app/hr/human_resources_theme.dart';
import 'package:dicsa_operacion/app/shared/app_shell.dart';
import 'package:dicsa_operacion/app/shared/dicsa_logo_mark.dart';
import 'package:dicsa_operacion/app/shared/ui_contract_core/theme/area_theme_scope.dart';

const preview = bool.fromEnvironment('HR_DOCUMENTATION_PREVIEW');
HrDocument fixture([
  HrDocumentCategory category = HrDocumentCategory.finiquito,
]) {
  final doc = hrDocumentBase(category, DateTime(2026, 10, 12));
  return doc.copy({
    'revision': 1,
    'data': {
      for (final field in doc.fields)
        field.key: switch (field.type) {
          'date' => '2026-10-12',
          'money' => '12345.67',
          'number' => '6',
          _ => switch (field.key) {
            'nombre' => 'MARÍA JOSÉ LÓPEZ',
            'empresa' => 'DICSA',
            'puesto' => 'Coordinadora de patio',
            'lugar' => 'Querétaro, México',
            'observaciones' => 'Documento de prueba para revisión visual.',
            'condiciones' =>
              'Las condiciones se capturan por Recursos Humanos y pueden ajustarse para cada documento.',
            'conceptos' =>
              'Concepto de prueba A: \$10,000.00\nConcepto de prueba B: \$2,345.67',
            _ => 'Información capturada para ${field.label.toLowerCase()}.',
          },
        },
    },
    'signatures': [
      for (final s in doc.signatures) {...s, 'name': 'María José López'},
    ],
  });
}

Future<void> app(
  WidgetTester tester,
  Widget child, {
  double width = 1360,
  double height = 1000,
  bool withShell = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (preview) {
    await tester.runAsync(() async {
      final fonts = FontLoader('Roboto')
        ..addFont(
          File(
            '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await fonts.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await icons.load();
    });
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: preview ? 'Roboto' : null),
      home: AreaThemeScope(
        tokens: humanResourcesAreaTokens,
        child: RepaintBoundary(
          key: const ValueKey('preview'),
          child: withShell
              ? AppShell(
                  background: const HumanResourcesAreaBackground(),
                  wrapBodyInGlass: false,
                  animateHeaderSlots: false,
                  animateBody: false,
                  headerBodySpacing: 8,
                  headerCenterSidePadding: 220,
                  minContentWidth: 900,
                  padding: const EdgeInsets.fromLTRB(28, 14, 20, 18),
                  leadingBuilder: (_, _) => HumanResourcesAreaHeaderButton(
                    label: 'Navegación',
                    icon: Icons.menu_rounded,
                    onTapSync: () {},
                  ),
                  centerBuilder: (_, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const DicsaLogoD(size: 54),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recursos Humanos',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Documentación RH',
                            style: TextStyle(
                              fontSize: 14,
                              color: humanResourcesAreaTokens.badgeText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailingBuilder: (_, _) => HumanResourcesAreaHeaderButton(
                    label: 'Cerrar sesión',
                    icon: Icons.logout_rounded,
                    onTapSync: () {},
                  ),
                  child: child,
                )
              : Scaffold(
                  backgroundColor: humanResourcesAreaTokens.primaryStrong,
                  body: Padding(
                    padding: const EdgeInsets.all(20),
                    child: child,
                  ),
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!preview) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('preview')),
  );
  final previousShadows = debugDisableShadows;
  try {
    debugDisableShadows = false;
    void repaint(RenderObject object) {
      object.markNeedsPaint();
      object.visitChildren(repaint);
    }

    repaint(boundary);
    await tester.pump();
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(
        '/private/tmp/dicsa_hr_documentation',
      ).create(recursive: true);
      await File(
        '/private/tmp/dicsa_hr_documentation/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  } finally {
    debugDisableShadows = previousShadows;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final category in HrDocumentCategory.values) {
    test(
      '${category.name}: editable format produces PDF with captured values',
      () async {
        final doc = fixture(category);
        expect(doc.validation(forPdf: true), isEmpty);
        expect(doc.renderedBody(), isNot(contains('{{')));
        final before = jsonEncode(doc.row);
        final bytes = await buildHrDocumentPdf(doc);
        expect(String.fromCharCodes(bytes.take(4)), '%PDF');
        expect(bytes.length, greaterThan(6000));
        expect(jsonEncode(doc.row), before);
        if (preview) {
          await Directory(
            '/private/tmp/dicsa_hr_documentation',
          ).create(recursive: true);
          await File(
            '/private/tmp/dicsa_hr_documentation/${category.name}.pdf',
          ).writeAsBytes(bytes);
        }
      },
    );
  }
  test(
    'copy as template clears employee and amounts and instantiation never changes source',
    () {
      final source = fixture().copy({'employee_id': 'e1'});
      final template = source.asTemplate();
      expect(template.id, isNot(source.id));
      expect(template.kind, 'template');
      expect(template.values, isEmpty);
      expect(template.row['employee_id'], isNull);
      expect(template.signatures.every((s) => s['name'] == ''), isTrue);
      final doc = template.instantiate(DateTime(2027, 1, 3));
      expect(doc.date, '2027-01-03');
      expect(doc.kind, 'generated');
      expect(doc.revision, 0);
      expect(doc.values, isEmpty);
      expect(doc.body, source.body);
      expect(source.values['monto'], '12345.67');
    },
  );
  test(
    'draft accepts missing data but PDF prevents incomplete or unknown values',
    () async {
      final blank = hrDocumentBase(
        HrDocumentCategory.finiquito,
        DateTime(2026, 10, 12),
      );
      expect(blank.validation(), isEmpty);
      expect(blank.validation(forPdf: true), isNotEmpty);
      await expectLater(buildHrDocumentPdf(blank), throwsFormatException);
      expect(fixture().copy({'body': '{{unknown}}'}).validation(), isNotEmpty);
      final bad = fixture().copy({
        'data': {
          ...fixture().values,
          'monto': '15.888',
          'inicio': '2026-02-30',
        },
      });
      expect(bad.validation(), hasLength(2));
      expect(hrDocumentMoney('12345.67'), r'$12,345.67');
      expect(hrDocumentValidDate('2028-02-29'), isTrue);
      expect(hrDocumentValidDate('2026-02-29'), isFalse);
    },
  );
  test(
    'long clauses and many short lines flow across pages without losing text',
    () async {
      final body =
          '${List.filled(180, 'Detalle extenso con nombres y montos que debe conservarse en la impresión.').join(' ')}\n\n${List.generate(130, (i) => 'Actividad ${i + 1}: revisar el proceso.').join('\n')}\n\nFIN DEL DOCUMENTO';
      final doc = fixture().copy({'body': body});
      final chunks = hrDocumentPdfParagraphs(body).toList();
      expect(
        chunks.every((c) => c.length <= 1400 && c.split('\n').length <= 15),
        isTrue,
      );
      final bytes = await buildHrDocumentPdf(doc);
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length,
        greaterThan(3),
      );
      if (preview) {
        await File(
          '/private/tmp/dicsa_hr_documentation/extenso.pdf',
        ).writeAsBytes(bytes);
      }
    },
  );
  test('upload restricts size and extensions', () {
    expect(
      () => HrDocumentUpload('x.exe', Uint8List(1)).validate(),
      throwsFormatException,
    );
    expect(
      () => HrDocumentUpload('x.pdf', Uint8List(0)).validate(),
      throwsFormatException,
    );
    expect(
      () => HrDocumentUpload(
        'x.pdf',
        Uint8List(hrDocumentFileLimit + 1),
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => HrDocumentUpload('x.PDF', Uint8List(1)).validate(),
      returnsNormally,
    );
  });
  test(
    'RH navigation includes documentation and respects Dirección access',
    () {
      Future<void> noop() async {}
      final sections = buildHumanResourcesAreaSections(
        openVacancies: () async {},
        activeScreen: HumanResourcesAreaScreen.documentation,
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
      );
      final doc = sections
          .expand((s) => s.items)
          .singleWhere((i) => i.title == 'Documentación RH');
      expect(doc.accented, isTrue);
      expect(doc.onTap, isNull);
      final access = buildHumanResourcesAccessItems(
        activeScreen: HumanResourcesAreaScreen.documentation,
        openDashboard: noop,
        canReturnToDirection: false,
        openDirectionDashboard: noop,
      );
      expect(
        access.map((i) => i.title),
        isNot(contains('Dashboard Dirección')),
      );
    },
  );
  testWidgets(
    'category opens on one click and allows both capture and upload',
    (tester) async {
      HrDocument? draft;
      await app(
        tester,
        HrDocumentWorkspace(
          records: const [],
          onEdit: (d) async => draft = d,
          onDownload: (_) async {},
          onOpenFile: (_) async {},
        ),
      );
      await capture(tester, 'categorias');
      await tester.tap(find.byKey(const ValueKey('category-telefono')));
      await tester.pumpAndSettle();
      expect(find.text('Llenar documento'), findsOneWidget);
      await tester.tap(find.text('Llenar documento'));
      await tester.pumpAndSettle();
      expect(draft!.kind, 'generated');
      expect(draft!.category, HrDocumentCategory.telefono);
      await tester.tap(find.text('Cargar archivo'));
      await tester.pumpAndSettle();
      expect(draft!.kind, 'uploaded');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('search, templates, selection and arrows retain correct detail', (
    tester,
  ) async {
    final first = fixture().copy({
      'id': '00000000-0000-4000-8000-000000000001',
      'title': 'Acuerdo A',
    });
    final second = fixture().copy({
      'id': '00000000-0000-4000-8000-000000000002',
      'title': 'Acuerdo B',
      'data': {...fixture().values, 'nombre': 'JUAN'},
    });
    final template = first.asTemplate();
    HrDocument? used;
    await app(
      tester,
      HrDocumentWorkspace(
        records: [second, first, template],
        initialCategory: HrDocumentCategory.finiquito,
        onEdit: (d) async => used = d,
        onDownload: (_) async {},
        onOpenFile: (_) async {},
      ),
    );
    await tester.tap(find.byKey(ValueKey('document-${first.id}')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ListTile>(find.byKey(ValueKey('document-${second.id}')))
          .selected,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(used!.id, second.id);
    await tester.enterText(find.byType(TextField), 'JUAN');
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('document-${first.id}')), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Plantillas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar plantilla'));
    await tester.pumpAndSettle();
    expect(used!.kind, 'generated');
    expect(used!.values, isEmpty);
  });
  testWidgets('library shows every category in the desktop viewport', (
    tester,
  ) async {
    await app(
      tester,
      HrDocumentWorkspace(
        records: const [],
        onDownload: (_) async {},
        onOpenFile: (_) async {},
      ),
      width: 1470,
      height: 900,
      withShell: true,
    );
    for (final category in HrDocumentCategory.values) {
      expect(
        find.byKey(ValueKey('category-${category.name}')).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester
            .getBottomRight(find.byKey(ValueKey('category-${category.name}')))
            .dy,
        lessThanOrEqualTo(882),
      );
    }
    expect(find.text('12 tipos disponibles'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'biblioteca');
  });
  testWidgets(
    'library combines accent-insensitive search and group and retains them on return',
    (tester) async {
      await app(
        tester,
        HrDocumentWorkspace(
          records: const [],
          onDownload: (_) async {},
          onOpenFile: (_) async {},
        ),
      );
      await tester.tap(find.byKey(const ValueKey('document-group-Políticas')));
      await tester.pumpAndSettle();
      expect(find.text('4 tipos disponibles'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('document-library-search')),
        'TELEFONO',
      );
      await tester.pumpAndSettle();
      expect(find.text('1 tipo disponible'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('category-telefono')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Documentación RH'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('document-library-search')),
            )
            .controller!
            .text,
        'TELEFONO',
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('document-group-Políticas')),
            )
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('document-group-Cartas')));
      await tester.pumpAndSettle();
      expect(find.text('No encontramos ese tipo de documento'), findsOneWidget);
      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('12 tipos disponibles'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('document-library-search')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'library counts active documents and templates separately and updates on refresh',
    (tester) async {
      final document = fixture(HrDocumentCategory.reglamento);
      final records = [
        document,
        document.asTemplate(),
        document.copy({'archived': true}),
      ];
      late StateSetter update;
      await app(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return HrDocumentWorkspace(
              records: List.of(records),
              onDownload: (_) async {},
              onOpenFile: (_) async {},
            );
          },
        ),
      );
      final card = find.byKey(const ValueKey('document-card-reglamento'));
      expect(
        find.descendant(
          of: card,
          matching: find.text('1 documento · 1 plantilla'),
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('document-library-search')),
        'reglamento',
      );
      await tester.pumpAndSettle();
      update(
        () => records.add(
          document.copy({'id': '00000000-0000-4000-8000-000000000003'}),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: card,
          matching: find.text('2 documentos · 1 plantilla'),
        ),
        findsOneWidget,
      );
      expect(find.text('1 tipo disponible'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'library cards open using keyboard and scroll on a small desktop',
    (tester) async {
      await app(
        tester,
        HrDocumentWorkspace(
          records: const [],
          onDownload: (_) async {},
          onOpenFile: (_) async {},
        ),
        width: 900,
        height: 650,
      );
      final card = find.byKey(const ValueKey('category-reglamento'));
      await tester.scrollUntilVisible(
        card,
        300,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(card.hitTestable(), findsOneWidget);
      Focus.of(
        tester.element(
          find.descendant(
            of: card,
            matching: find.text('Reglamento interno de trabajo'),
          ),
        ),
      ).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Reglamento interno de trabajo'), findsOneWidget);
      expect(find.text('Llenar documento'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'single-click fields save edited name, date, amounts and custom body',
    (tester) async {
      HrDocumentSaveOperation? saved;
      final doc = fixture();
      await app(
        tester,
        HrDocumentEditor(
          document: doc,
          onSave: (op) async {
            saved = op;
            return op.document;
          },
          onPdf: (_) async {},
        ),
      );
      await tester.tap(find.byKey(const ValueKey('field-nombre')));
      await tester.enterText(
        find.byKey(const ValueKey('field-nombre')),
        'ANA EDITADA',
      );
      await tester.enterText(
        find.byKey(const ValueKey('document-title')),
        'Convenio corregido',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('field-monto')));
      await tester.enterText(
        find.byKey(const ValueKey('field-monto')),
        '18000.50',
      );
      await tester.tap(find.text('Texto y firmas'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('document-body')));
      await tester.enterText(
        find.byKey(const ValueKey('document-body')),
        'Documento para {{nombre}} por {{monto}} al {{fecha}}.',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(saved!.document.values['nombre'], 'ANA EDITADA');
      expect(saved!.document.values['monto'], '18000.50');
      expect(saved!.document.title, 'Convenio corregido');
      expect(saved!.document.renderedBody(), contains(r'$18,000.50'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('capture can select personnel and retains editable snapshot', (
    tester,
  ) async {
    HrDocumentSaveOperation? saved;
    await app(
      tester,
      HrDocumentEditor(
        document: fixture(),
        employees: const [
          {
            'id': 'p1',
            'nombre': 'ANA PERSONAL',
            'empresa': 'OTRA EMPRESA',
            'puesto': 'CONTADORA',
          },
        ],
        onSave: (op) async {
          saved = op;
          return op.document;
        },
        onPdf: (_) async {},
      ),
    );
    await tester.tap(find.text('Elegir colaborador'));
    await tester.pumpAndSettle();
    final search = find.byType(TextField).last;
    expect(tester.widget<TextField>(search).focusNode!.hasFocus, isTrue);
    await tester.enterText(search, 'ANA');
    await tester.pumpAndSettle();
    await tester.tap(find.text('ANA PERSONAL · OTRA EMPRESA'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('field-nombre')),
      'ANA CORREGIDA',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(saved!.document.row['employee_id'], 'p1');
    expect(saved!.document.values['empresa'], 'OTRA EMPRESA');
    expect(saved!.document.values['nombre'], 'ANA CORREGIDA');
    expect(saved!.document.values['puesto'], 'CONTADORA');
  });
  testWidgets('upload cancel keeps editor and no record until file and save', (
    tester,
  ) async {
    var picks = 0;
    HrDocumentSaveOperation? saved;
    await app(
      tester,
      HrDocumentEditor(
        document: hrDocumentBase(
          HrDocumentCategory.reglamento,
          DateTime(2026, 10, 12),
          kind: 'uploaded',
        ),
        pickFile: () async => ++picks == 1
            ? null
            : HrDocumentUpload(
                'Reglamento.pdf',
                Uint8List.fromList([37, 80, 68, 70]),
              ),
        onSave: (op) async {
          saved = op;
          return op.document;
        },
        onPdf: (_) async {},
      ),
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    await tester.tap(find.text('Seleccionar archivo'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    await tester.tap(find.text('Seleccionar archivo'));
    await tester.pumpAndSettle();
    expect(find.text('Reglamento.pdf'), findsOneWidget);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(saved!.upload!.name, 'Reglamento.pdf');
  });
  testWidgets(
    'unknown save response freezes edits and reuses exact request when retried',
    (tester) async {
      var attempts = 0;
      final operations = <HrDocumentSaveOperation>[];
      await app(
        tester,
        HrDocumentEditor(
          document: fixture(),
          onSave: (op) async {
            operations.add(op);
            op.confirmationPending = true;
            if (++attempts == 1) {
              throw const SocketException('Connection interrupted');
            }
            return op.document;
          },
          onPdf: (_) async {},
        ),
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('document-title')))
            .enabled,
        isFalse,
      );
      await tester.tap(find.text('Reintentar guardado'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(identical(operations[0], operations[1]), isTrue);
    },
  );
  testWidgets(
    'template screen and document preview remain within small desktop canvas',
    (tester) async {
      await app(
        tester,
        HrDocumentEditor(
          document: fixture(HrDocumentCategory.acta),
          onSave: (op) async => op.document,
          onPdf: (_) async {},
        ),
        width: 1050,
        height: 750,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, 'captura');
      await tester.tap(find.text('Vista previa'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, 'vista_previa');
    },
  );
  testWidgets('date picker and PDF use the saved edited revision', (
    tester,
  ) async {
    HrDocument? printed;
    await app(
      tester,
      HrDocumentEditor(
        document: fixture(),
        onSave: (op) async => op.document.copy({'revision': 2}),
        onPdf: (d) async => printed = d,
      ),
    );
    await tester.tap(find.text('12/10/2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('14'));
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('field-nombre')),
      'NOMBRE FINAL',
    );
    await tester.tap(find.text('Guardar y PDF'));
    await tester.pumpAndSettle();
    expect(printed!.revision, 2);
    expect(printed!.date, '2026-10-14');
    expect(printed!.values['nombre'], 'NOMBRE FINAL');
  });
  testWidgets('template adds custom data and persists reusable format', (
    tester,
  ) async {
    HrDocumentSaveOperation? saved;
    await app(
      tester,
      HrDocumentEditor(
        document: fixture().asTemplate(),
        onSave: (op) async {
          saved = op;
          return op.document;
        },
        onPdf: (_) async {},
      ),
    );
    await tester.ensureVisible(find.text('Agregar dato'));
    await tester.tap(find.text('Agregar dato'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Importe adicional');
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(saved!.document.fields.last.label, 'Importe adicional');
    expect(saved!.document.body, contains('{{dato_1}}'));
    expect(saved!.document.values, isEmpty);
    expect(saved!.document.validation(), isEmpty);
  });
  testWidgets(
    'modal prevents duplicate save and closes after success; Escape cancels',
    (tester) async {
      final completion = Completer<HrDocument>();
      var saves = 0;
      HrDocument? returned;
      await app(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              returned = await showDialog<HrDocument>(
                context: context,
                builder: (_) => AreaThemeScope(
                  tokens: humanResourcesAreaTokens,
                  child: HrDocumentEditor(
                    document: fixture(),
                    onSave: (op) async {
                      saves++;
                      return completion.future;
                    },
                    onPdf: (_) async {},
                  ),
                ),
              );
            },
            child: const Text('Abrir editor'),
          ),
        ),
      );
      await tester.tap(find.text('Abrir editor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      expect(saves, 1);
      completion.complete(fixture());
      await tester.pumpAndSettle();
      expect(returned, isNotNull);
      expect(find.byType(HrDocumentEditor), findsNothing);
      await tester.tap(find.text('Abrir editor'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(HrDocumentEditor), findsNothing);
      expect(saves, 1);
    },
  );
  testWidgets('workflow visual preview', (tester) async {
    await app(
      tester,
      HrDocumentWorkspace(
        records: [fixture(), fixture().asTemplate()],
        initialCategory: HrDocumentCategory.finiquito,
        onEdit: (_) async {},
        onDownload: (_) async {},
        onOpenFile: (_) async {},
      ),
    );
    expect(tester.takeException(), isNull);
    await capture(tester, 'documentos');
  });
}
