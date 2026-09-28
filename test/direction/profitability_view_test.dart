import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/direction/direction_theme.dart';
import 'package:dicsa_operacion/app/shared/ui_contract_core/theme/area_theme_scope.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_models.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_repository.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_view.dart';
import 'package:dicsa_operacion/app/direction/profitability/profitability_forms.dart';
import 'profitability_fixtures.dart';
import 'profitability_account_test.dart' show accountFixture;
import 'profitability_operating_test.dart' show operatingMaster;
import 'package:dicsa_operacion/app/direction/profitability/profitability_parameters.dart';

class MemoryProfitRepo extends ProfitabilityRepository {
  ProfitSources? overrideSources;
  ProfitReview review = const ProfitReview();
  ProfitMaster master = const ProfitMaster();
  int reads = 0, writes = 0, snapshots = 0;
  bool fail = false, failSave = false, infer = false;
  @override
  Future<ProfitBundle> load(ProfitPeriod period) async {
    reads++;
    if (fail) throw StateError('Fuente no disponible');
    return ProfitBundle(
      overrideSources ?? (infer ? accountFixture() : profitFixture()),
      review,
      master,
      infer,
    );
  }

  @override
  Future<ProfitReview> save(ProfitPeriod p, ProfitReview r) async {
    if (failSave) throw StateError('Conflicto de versión');
    writes++;
    return review = r.copyWith(revision: r.revision + 1);
  }

  @override
  Future<ProfitMaster> saveMaster(ProfitMaster next) async {
    if (failSave) throw StateError('Conflicto de versión');
    writes++;
    return master = ProfitMaster(
      revision: next.revision + 1,
      rules: next.rules,
    );
  }

  @override
  Future<String> saveSnapshot(ProfitAnalysis a) async {
    snapshots++;
    return 'cut';
  }

  @override
  Future<List<ProfitRow>> history(ProfitPeriod p) async => [];
}

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
  Widget app(Widget child, {GlobalKey? boundary}) => MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(
      body: AreaThemeScope(
        tokens: directionAreaTokens,
        child: RepaintBoundary(
          key: boundary,
          child: Stack(
            children: [
              const Positioned.fill(child: DirectionExecutiveBackground()),
              Padding(padding: const EdgeInsets.all(20), child: child),
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> surface(
    WidgetTester t, [
    Size s = const Size(1440, 1050),
  ]) async {
    await t.binding.setSurfaceSize(s);
    addTearDown(() => t.binding.setSurfaceSize(null));
  }

  Future<void> capture(WidgetTester t, GlobalKey key, String filename) async {
    if (Platform.environment['DICSA_PROFIT_QA'] != '1') return;
    await t.runAsync(() async {
      final picture =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      final data = await picture.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/private/tmp/$filename',
      ).writeAsBytes(data!.buffer.asUint8List());
      picture.dispose();
    });
  }

  testWidgets(
    'exit assumptions validate, Escape cancels, and local savings never write source data',
    (t) async {
      await surface(t);
      final repo = MemoryProfitRepo()..infer = true;
      await t.pumpWidget(
        app(
          ProfitabilityView(
            repository: repo,
            initialPeriod: ProfitPeriod.pilot(),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Consolidado'));
      await t.pumpAndSettle();
      final scroll = find
          .descendant(
            of: find.byKey(const ValueKey('profit-consolidated')),
            matching: find.byType(Scrollable),
          )
          .first;
      await t.scrollUntilVisible(
        find.text('Ajustar ahorros y salida'),
        250,
        scrollable: scroll,
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Ajustar ahorros y salida'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ajustar ahorros y salida'));
      await t.pumpAndSettle();
      final savings = find.widgetWithText(
        TextFormField,
        'Personal compartido y administración · ahorro (%)',
      );
      await t.enterText(savings, '101');
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.text('Supuestos de salida · PLANTA A'), findsOneWidget);
      await t.enterText(savings, '50');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Supuestos de salida · PLANTA A'), findsNothing);
      await t.tap(find.text('Ajustar ahorros y salida'));
      await t.pumpAndSettle();
      expect(t.widget<TextFormField>(savings).controller!.text, '0.0');
      await t.enterText(savings, '50');
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.text('Supuestos de salida · PLANTA A'), findsNothing);
      expect(repo.writes, 0);
      expect(repo.snapshots, 0);
      repo.fail = true;
      await t.pump(const Duration(seconds: 31));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Se muestra la última lectura'),
        findsOneWidget,
      );
      final edit = t.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Ajustar ahorros y salida'),
      );
      expect(edit.onPressed, isNull);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'consolidated ignores search, simulates locally, defers refresh during editing and resets period assumptions',
    (t) async {
      await surface(t);
      final repo = MemoryProfitRepo()..infer = true;
      final key = GlobalKey();
      await t.pumpWidget(
        app(
          ProfitabilityView(
            repository: repo,
            initialPeriod: ProfitPeriod.pilot(),
          ),
          boundary: key,
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextField, 'Buscar empresa'),
        'NO COINCIDE',
      );
      await t.pumpAndSettle();
      expect(find.text('Empresas · 0 cuentas'), findsOneWidget);
      await t.tap(find.text('Consolidado'));
      await t.pumpAndSettle();
      expect(find.text('Consolidado Compras Mayoreo'), findsOneWidget);
      expect(find.text('Simular · PLANTA A'), findsOneWidget);
      expect(find.text('Buscar empresa'), findsNothing);
      expect(t.takeException(), isNull);
      await capture(t, key, 'dicsa_profit_consolidated.png');
      final scroll = find
          .descendant(
            of: find.byKey(const ValueKey('profit-consolidated')),
            matching: find.byType(Scrollable),
          )
          .first;
      await t.scrollUntilVisible(
        find.text('Ajustar operación'),
        250,
        scrollable: scroll,
      );
      await t.tap(find.text('Ajustar operación'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Cambiar precios y viajes'),
        250,
        scrollable: scroll,
      );
      await t.tap(find.text('Cambiar precios y viajes'));
      await t.pumpAndSettle();
      final reads = repo.reads;
      await t.pump(const Duration(seconds: 31));
      expect(repo.reads, reads);
      final purchase = find.widgetWithText(
        TextFormField,
        'Cambio precio de compra (%)',
      );
      await t.enterText(purchase, '-10');
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.textContaining('Compra -10.0%'), findsOneWidget);
      expect(repo.writes, 0);
      expect(repo.snapshots, 0);
      await t.pump(const Duration(seconds: 31));
      await t.pumpAndSettle();
      expect(find.textContaining('Compra -10.0%'), findsOneWidget);
      await t.binding.setSurfaceSize(const Size(600, 1000));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await capture(t, key, 'dicsa_profit_consolidated_narrow.png');
      await t.tap(find.text('Esta semana'));
      await t.pumpAndSettle();
      expect(find.textContaining('Compra -10.0%'), findsNothing);
      expect(repo.writes, 0);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'pending classification stays visible across company and consolidated tabs',
    (t) async {
      await surface(t);
      final key = GlobalKey();
      final repo = MemoryProfitRepo()
        ..infer = true
        ..overrideSources = accountFixture(
          overrides: {
            'finanzas_supplier_invoices': [
              {
                'id': 'unclassified',
                'invoice_date': '2026-09-12',
                'provider_name_snapshot': 'MARICRUZ QUIROGA ACOSTA',
                'total_amount': 465920,
                'origin_type': 'MANUAL',
                'status': 'pendiente',
              },
            ],
          },
        );
      await t.pumpWidget(
        app(
          ProfitabilityView(
            repository: repo,
            initialPeriod: ProfitPeriod.pilot(),
          ),
          boundary: key,
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Resultado provisional:'), findsOneWidget);
      expect(t.takeException(), isNull);
      await capture(t, key, 'dicsa_profit_pending.png');
      await t.tap(find.text('Consolidado'));
      await t.pumpAndSettle();
      expect(find.textContaining('Resultado provisional:'), findsOneWidget);
      await t.binding.setSurfaceSize(const Size(760, 1000));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await capture(t, key, 'dicsa_profit_pending_narrow.png');
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'simple operational statement opens by default, explains estimates and preserves failed concept draft',
    (t) async {
      await surface(t);
      final repo = MemoryProfitRepo()..infer = true;
      final key = GlobalKey();
      await t.pumpWidget(
        app(
          ProfitabilityView(
            repository: repo,
            initialPeriod: ProfitPeriod.pilot(),
          ),
          boundary: key,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Lo que genera'), findsOneWidget);
      expect(find.text('Lo que cuesta atender'), findsOneWidget);
      expect(find.text('Información insuficiente'), findsNothing);
      expect(find.text('Sin cuantificar'), findsNothing);
      expect(find.text('Parámetros'), findsNothing);
      expect(t.takeException(), isNull);
      await capture(t, key, 'dicsa_profit_operational.png');
      await t.tap(find.byKey(const ValueKey('account:site:s1')));
      await t.pumpAndSettle();
      expect(find.text('¿Dónde ganamos y dónde perdemos?'), findsOneWidget);
      expect(t.takeException(), isNull);
      await capture(t, key, 'dicsa_profit_operational_detail.png');
      await t.binding.setSurfaceSize(const Size(760, 1000));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await capture(t, key, 'dicsa_profit_operational_narrow.png');
      final scroll = find
          .descendant(
            of: find.byKey(const ValueKey('account-detail:site:s1')),
            matching: find.byType(Scrollable),
          )
          .first;
      await t.scrollUntilVisible(
        find.text('Cómo se calculó'),
        300,
        scrollable: scroll,
      );
      await t.drag(scroll, const Offset(0, -180));
      await t.pumpAndSettle();
      await t.tap(find.text('Cómo se calculó'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('del importe del modelo usa estimaciones'),
        findsOneWidget,
      );
      await t.tap(find.text('Ajustar concepto de esta cuenta'));
      await t.pumpAndSettle();
      final reads = repo.reads;
      await t.pump(const Duration(seconds: 31));
      expect(repo.reads, reads);
      final rate = find.widgetWithText(TextFormField, 'Importe unitario');
      final note = find.widgetWithText(TextFormField, 'Base del ajuste');
      await t.enterText(rate, '3000');
      await t.enterText(note, 'Condición acordada');
      repo.failSave = true;
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();
      expect(find.textContaining('Conflicto de versión'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Concepto · PLANTA A'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'executive results, five tabs, drill-down, narrow layout and parameter conflict retain draft',
    (t) async {
      await surface(t);
      final repo = MemoryProfitRepo()..master = operatingMaster();
      final key = GlobalKey();
      await t.pumpWidget(
        app(
          ProfitabilityView(
            simple: false,
            repository: repo,
            initialPeriod: ProfitPeriod.pilot(),
          ),
          boundary: key,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Aporte operativo'), findsWidgets);
      expect(find.textContaining('1,310.00'), findsWidgets);
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Esta semana'), findsOneWidget);
      expect(find.text('Este mes'), findsOneWidget);
      expect(t.takeException(), isNull);
      await capture(t, key, 'dicsa_profit_executive.png');
      await t.tap(find.text('Empresas'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('executive:site:s1')));
      await t.pumpAndSettle();
      expect(find.text('APORTE OPERATIVO · PARCIAL'), findsOneWidget);
      await capture(t, key, 'dicsa_profit_executive_detail.png');
      await t.tap(find.text('Tendencias'));
      await t.pumpAndSettle();
      expect(find.text('Tendencia del aporte operativo'), findsOneWidget);
      await t.binding.setSurfaceSize(const Size(760, 1000));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(find.text('Resumen'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await capture(t, key, 'dicsa_profit_executive_narrow.png');
      await t.tap(find.text('Parámetros'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Editar parámetro y vigencia').first);
      await t.pumpAndSettle();
      final reads = repo.reads;
      await t.pump(const Duration(seconds: 31));
      expect(repo.reads, reads);
      repo.failSave = true;
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();
      expect(find.textContaining('Conflicto de versión'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(repo.writes, 0);
      expect(repo.reads, greaterThan(reads));
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('report tabs, navigation, responsive sizing and silent refresh', (
    t,
  ) async {
    await surface(t);
    final repo = MemoryProfitRepo(), key = GlobalKey();
    await t.pumpWidget(
      app(ProfitabilityView(repository: repo, simple: false), boundary: key),
    );
    await t.pumpAndSettle();
    expect(find.text('¿Cuánto aporta cada empresa?'), findsOneWidget);
    await t.tap(find.text('Auditoría y conciliación'));
    await t.pumpAndSettle();
    expect(find.text('Buscar empresa'), findsOneWidget);
    expect(find.textContaining('Información insuficiente'), findsWidgets);
    expect(t.takeException(), isNull);
    await capture(t, key, 'dicsa_profit_companies.png');
    await t.tap(find.byKey(const ValueKey('company:compras:c1')));
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();
    await t.tap(find.text('Costos y conciliación'));
    await t.pumpAndSettle();
    expect(find.textContaining('documentos pendientes'), findsOneWidget);
    await capture(t, key, 'dicsa_profit_costs.png');
    await t.tap(find.text('Fuentes y cobertura'));
    await t.pumpAndSettle();
    expect(find.text('Cobertura del corte'), findsOneWidget);
    await t.binding.setSurfaceSize(const Size(760, 1000));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.text('Detalle y evidencia'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await capture(t, key, 'dicsa_profit_narrow.png');
    final reads = repo.reads;
    await t.pump(const Duration(seconds: 31));
    await t.pumpAndSettle();
    expect(repo.reads, greaterThan(reads));
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'failed refresh shows stale state and disables writing and export',
    (t) async {
      await surface(t);
      final repo = MemoryProfitRepo();
      await t.pumpWidget(
        app(ProfitabilityView(repository: repo, simple: false)),
      );
      await t.pumpAndSettle();
      repo.fail = true;
      await t.pump(const Duration(seconds: 31));
      await t.pumpAndSettle();
      expect(find.textContaining('última consulta'), findsOneWidget);
      expect(
        t
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Guardar corte'),
            )
            .onPressed,
        isNull,
      );
      expect(
        t
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'CSV'))
            .onPressed,
        isNull,
      );
      repo.fail = false;
      await t.pump(const Duration(seconds: 31));
      await t.pumpAndSettle();
      expect(
        t
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'CSV'))
            .onPressed,
        isNotNull,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'coverage editing preserves focus and defers refresh, Escape cancels',
    (t) async {
      await surface(t);
      final repo = MemoryProfitRepo();
      await t.pumpWidget(
        app(ProfitabilityView(repository: repo, simple: false)),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Auditoría y conciliación'));
      await t.pumpAndSettle();
      await t.tap(find.text('Revisar cobertura'));
      await t.pumpAndSettle();
      final reads = repo.reads;
      await t.pump(const Duration(seconds: 31));
      await t.pumpAndSettle();
      expect(repo.reads, reads);
      await t.tap(find.byKey(const ValueKey('note')));
      await t.enterText(find.byKey(const ValueKey('note')), 'Evidencia');
      await t.sendKeyEvent(LogicalKeyboardKey.backspace);
      expect(repo.writes, 0);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Cancelar'), findsNothing);
      expect(repo.writes, 0);
      expect(repo.reads, greaterThan(reads));
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'allocation validates totals, retains failed draft, Enter saves and Escape cancels',
    (t) async {
      await surface(t);
      var writes = 0;
      var failing = true;
      await t.pumpWidget(
        app(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showProfitDistribution(
                  context,
                  title: 'Asignar prueba',
                  description: 'Reparto de combustible',
                  options: const {'s1': 'PLANTA A', 's2': 'PLANTA B'},
                  values: const {'s1': 1},
                  note: 'Km medidos',
                  complete: true,
                  onSave: (values, note) async {
                    if (failing) throw StateError('Conflicto');
                    expect(values.values.reduce((a, b) => a + b), 1);
                    writes++;
                  },
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Abrir'));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.textContaining('Conflicto'), findsOneWidget);
      expect(find.text('Km medidos'), findsOneWidget);
      expect(writes, 0);
      failing = false;
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();
      expect(writes, 1);
      expect(find.text('Asignar prueba'), findsNothing);
      await t.tap(find.text('Abrir'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Quitar participación'));
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();
      expect(find.textContaining('debe sumar 100%'), findsOneWidget);
      expect(writes, 1);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Asignar prueba'), findsNothing);
    },
  );
}
