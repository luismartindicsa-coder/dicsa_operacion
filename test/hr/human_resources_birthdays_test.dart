import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/hr/human_resources_birthdays.dart';
import 'package:dicsa_operacion/app/hr/human_resources_dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> profile(
  int id,
  String name,
  String? curp, {
  String status = 'activo',
}) => {
  'id': id,
  'nombre': name,
  'empresa': 'EMPRESA DE PRUEBA',
  'curp': curp,
  'employment_status': status,
};

final today = DateTime(2026, 9, 9);
final profiles = [
  profile(4, 'DANIELA LUNA', 'LUDD980927MGTNNN01'),
  profile(2, 'CARLOS MÉNDEZ', 'MECC900918HGTNNN01'),
  profile(1, 'ANA LÓPEZ', 'LOAA920909MGTNNN01'),
  profile(3, 'MARÍA TORRES', 'TOMM000918MGTNNNA1'),
  profile(5, 'OTRO MES', 'MEMO900818HGTNNN01'),
  profile(6, 'SIN CURP', null),
  profile(7, 'BAJA', 'BABB900909HGTNNN01', status: 'baja'),
];

const capturePreview = bool.fromEnvironment('HR_BIRTHDAY_PREVIEW');

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!capturePreview) return;
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/hr_birthday_cake.png'),
      key.currentContext!,
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '/private/tmp/dicsa_birthday_$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!capturePreview) return;
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
    'CURP date uses the century marker and normalizes case and whitespace',
    () {
      expect(
        hrBirthDateFromCurp('  loaa920909mgtnnn01  ', today: today),
        DateTime(1992, 9, 9),
      );
      expect(
        hrBirthDateFromCurp('TOMM000918MGTNNNA1', today: today),
        DateTime(2000, 9, 18),
      );
    },
  );

  test('missing, malformed, impossible and future dates are omitted', () {
    for (final curp in [
      null,
      '',
      'SIN CURP',
      'LOAA921309MGTNNN01',
      'LOAA920931MGTNNN01',
      'LOAA000229MGTNNN01',
      'LOAA990909MGTNNNA1',
    ]) {
      expect(hrBirthDateFromCurp(curp, today: today), isNull, reason: '$curp');
    }
  });

  test('Feb 29 stays in February in a non-leap dashboard year', () {
    final rows = [profile(1, 'BISIESTO', 'BIBB000229HGTNNNA1')];
    final feb = HrBirthdayMonth.fromProfiles(rows, now: DateTime(2026, 2, 1));
    expect(feb.employees.single.day, 29);
    expect(
      HrBirthdayMonth.fromProfiles(rows, now: DateTime(2026, 3, 1)).employees,
      isEmpty,
    );
  });

  test(
    'month list keeps past and upcoming birthdays, sorts and excludes bajas',
    () {
      final data = HrBirthdayMonth.fromProfiles([
        ...profiles,
        profiles.first,
      ], now: today);
      expect(data.employees.map((employee) => employee.employeeId), [
        '1',
        '2',
        '3',
        '4',
      ]);
      expect(data.missingBirthDateCount, 1);
      expect(data.monthLabel, 'Septiembre · 2026');
      expect(
        HrBirthdayMonth.fromProfiles(
          profiles,
          now: DateTime(2026, 10, 1),
        ).employees,
        isEmpty,
      );
    },
  );

  testWidgets(
    'card uses calendar month, shows three previews and opens all birthdays',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            home: Scaffold(
              backgroundColor: const Color(0xFF24103F),
              body: Center(
                child: SizedBox(
                  width: 390,
                  child: hrDashboardBirthdayCardForTesting(
                    profiles: profiles,
                    today: today,
                    selectedPeriodLabel:
                        'Periodo 35 semanal · 21/08/2026 - 27/08/2026',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Septiembre · 2026'), findsOneWidget);
      expect(find.text('ANA LÓPEZ'), findsOneWidget);
      expect(find.text('DANIELA LUNA'), findsNothing);
      expect(find.text('HOY'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, boundary, 'card');

      await tester.tap(find.text('Ver todos'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('DANIELA LUNA'), findsOneWidget);
      expect(find.text('4 colaboradores'), findsOneWidget);
      expect(
        find.textContaining('1 expediente sin fecha válida'),
        findsOneWidget,
      );
      expect(find.text('BAJA'), findsNothing);
      expect(find.text('OTRO MES'), findsNothing);
      expect(tester.takeException(), isNull);
      await capture(tester, boundary, 'popup');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets(
    'empty month works at narrow width and closes with the header button',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: hrDashboardBirthdayCardForTesting(
                  profiles: profiles,
                  today: DateTime(2026, 10, 1),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cumpleaños del mes'));
      await tester.pumpAndSettle();
      expect(
        find.text('No hay cumpleaños registrados este mes.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets(
    'long month scrolls in a small popup and a compact card does not overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final many = List.generate(
        30,
        (index) => profile(
          index + 1,
          'COLABORADOR CON NOMBRE LARGO ${index + 1}',
          'LOAA90${'09'}${(index + 1).toString().padLeft(2, '0')}MGTNNN01',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 270,
                child: hrDashboardBirthdayCardForTesting(
                  profiles: many,
                  today: today,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Ver todos'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('COLABORADOR CON NOMBRE LARGO 30'),
        300,
        scrollable: find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('COLABORADOR CON NOMBRE LARGO 30'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
