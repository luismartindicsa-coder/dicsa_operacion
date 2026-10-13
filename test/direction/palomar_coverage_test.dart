import 'dart:io';
import 'dart:ui' as ui;

import 'package:dicsa_operacion/app/direction/direction_shipments_store.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_models.dart';
import 'package:dicsa_operacion/app/direction/expected_income/expected_income_repository.dart';
import 'package:dicsa_operacion/app/direction/expected_income/palomar_coverage.dart';
import 'package:dicsa_operacion/app/direction/expected_income/palomar_coverage_view.dart';
import 'package:dicsa_operacion/app/direction/expected_income/palomar_materials.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expected_income_test.dart' as f;
import 'expected_income_view_test.dart' as v;
import 'palomar_dispatch_fixtures.dart' as d;

DateTime day(int n) => f.incomeWeek.add(Duration(days: n));
PalomarIncomeMovement movement(
  int date,
  int cents, {
  String? report,
  bool projected = false,
  String? concept,
}) => PalomarIncomeMovement(
  id: '$date-$cents',
  date: day(date),
  signedCents: cents,
  concept: concept ?? (cents > 0 ? 'chequeLiberado' : 'remisionAplicada'),
  reportId: report,
  projected: projected,
);
DirectionShipmentPlanRecord shipment(
  String id,
  int date, {
  int bales = 40,
  String status = 'confirmado',
}) => f.incomeShipment(
  id: id,
  day: date,
  client: 'EL PALOMAR',
  bales: bales,
  status: status,
);
ExpectedIncomeData data({
  int? receipt = 4,
  int? fiscal,
  List<PalomarIncomeMovement> movements = const [],
  List<DirectionShipmentPlanRecord> shipments = const [],
  List<IncomeSale> sales = const [],
  Map<String, String> links = const {},
  List<IncomeMaterialRule> materials = f.incomeMaterials,
  Map<String, double> prices = const {},
  List<PalomarMaterialQuote> quotes = const [],
}) => ExpectedIncomeData(
  materials: materials,
  clients: f.incomeClients,
  sales: sales,
  palomarCoverageLinks: links,
  clientMaterialPrices: prices,
  palomarCoverageShipments: shipments,
  palomarCoverageMaterials: quotes,
  palomarMovements: movements,
  palomarSchedule: PalomarReceiptSchedule(
    week: day(0),
    cashDate: receipt == null ? null : day(receipt),
    fiscalDate: fiscal == null ? null : day(fiscal),
  ),
);
PalomarCoverage project(ExpectedIncomeData source, {int now = 0}) =>
    projectPalomarCoverage(
      bundle: f.incomeBundle(shipments: []),
      data: source,
      now: day(now),
    );

DirectionShipmentPlanRecord bulkShipment(
  String id,
  String material,
  int quantity,
  int date,
) => DirectionShipmentPlanRecord.fromRow({
  'id': id,
  'ship_date': day(date).toIso8601String(),
  'client_name': 'EL PALOMAR',
  'planning_material_code': material,
  'quantity_unit': 'KG',
  'planned_units': quantity,
  'status': 'confirmado',
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'dispatch table combines kilograms and bales without mixing quantities or double counting agenda',
    () {
      final p = project(
        data(
          movements: [movement(-7, 10000000)],
          shipments: [
            shipment('carton', 0, bales: 10),
            bulkShipment('scrap', 'CHATARRA', 1000, 1),
          ],
          quotes: const [
            PalomarMaterialQuote('CHATARRA', 'Chatarra', 'kg', 5),
            PalomarMaterialQuote('PLASTICO', 'Plástico', 'kg', 8.5),
          ],
        ),
      );
      expect(p.projectedBalance, 7750000);
      final sends = p.sends('PLASTICO');
      expect(sends.where((s) => !s.additional).map((s) => s.unit).toSet(), {
        'kg',
        'pacas',
      });
      final extra = sends.singleWhere((s) => s.additional);
      expect(extra.quantity, 9118);
      expect(extra.unit, 'kg');
      expect(extra.amount, 7750300);
      expect(p.balanceWithSends('PLASTICO'), -300);
      expect(sends.every((s) => !s.date.isAfter(p.deadline!)), true);
    },
  );
  test(
    'already shipped material is not requested again and rounded amount matches actual quantity',
    () {
      final p = project(
        data(
          movements: [movement(-7, 10000000)],
          shipments: [shipment('done', -1, bales: 10, status: 'embarcado')],
        ),
      );
      expect(p.events.single.alreadyShipped, true);
      final sends = p.sends('PACA_NACIONAL');
      expect(sends.every((s) => s.additional), true);
      expect(sends.single.amount, sends.single.quantity! * 175000);
      expect(p.balanceWithSends('PACA_NACIONAL'), lessThanOrEqualTo(0));
    },
  );
  test(
    'catalog units and sub-cent prices preserve units and enough value to cover the account',
    () {
      final p = project(
        data(
          movements: [movement(-7, 101)],
          quotes: const [
            PalomarMaterialQuote('MAYOREO:tarima', 'Tarima', 'pzas', 0.505),
            PalomarMaterialQuote('MAYOREO:papel', 'Papel archivo', 'kg', 0.004),
          ],
        ),
      );
      final pieces = p.sends('MAYOREO:tarima').single;
      expect(pieces.quantity, 2);
      expect(pieces.unit, 'pzas');
      expect(pieces.amount, 101);
      expect(p.balanceWithSends('MAYOREO:tarima'), 0);
      final kg = p.sends('MAYOREO:papel').single;
      expect(kg.unit, 'kg');
      expect(kg.amount, greaterThanOrEqualTo(101));
      expect(
        const PalomarMaterialQuote('x', 'x', '', 10).quantityFor(100),
        isNull,
      );
    },
  );
  test(
    'missing bale conversion never uses a per kg price as a price per bale',
    () {
      final p = project(
        data(
          movements: [movement(-7, 10000000)],
          shipments: [
            f.incomeShipment(
              client: 'EL PALOMAR',
              material: 'CAPLE',
              bales: 40,
            ),
          ],
          quotes: const [PalomarMaterialQuote('CAPLE', 'Caple', 'kg', 3)],
        ),
      );
      expect(p.complete, false);
      expect(p.events.single.signedCents, isNull);
      expect(p.events.single.unit, 'pacas');
      expect(p.needs, isEmpty);
    },
  );
  test(
    'catalog keeps commercial grades separate and uses only Palomar prices and explicit units',
    () {
      final quotes = palomarCatalogQuotes(
        materials: [
          {
            'id': 'metal',
            'code': 'METAL',
            'name': 'METAL',
            'unit': 'KG',
            'is_active': true,
          },
          {
            'id': 'archivo',
            'code': 'PAPEL_ARCHIVO',
            'name': 'PAPEL ARCHIVO',
            'unit': 'KG',
            'is_active': true,
          },
          {
            'id': 'revuelto',
            'code': 'PAPEL_REVUELTO',
            'name': 'PAPEL REVUELTO',
            'unit': 'KG',
            'is_active': true,
          },
          {
            'id': 'tarima',
            'code': 'TARIMA',
            'name': 'TARIMA',
            'unit': 'PZA',
            'is_active': true,
          },
        ],
        prices: [
          {
            'company_id': 'p',
            'material_id': 'metal',
            'final_price': 4,
            'is_active': true,
          },
          {
            'company_id': 'p',
            'material_id': 'archivo',
            'final_price': 3,
            'is_active': true,
          },
          {
            'company_id': 'p',
            'material_id': 'revuelto',
            'final_price': 1,
            'is_active': true,
          },
          {
            'company_id': 'other',
            'material_id': 'tarima',
            'final_price': 100,
            'is_active': true,
          },
        ],
        clients: [
          {'id': 'p', 'name': 'EL PALOMAR', 'is_active': true},
        ],
        rule: f.incomeClients.last,
      );
      expect(quotes.singleWhere((q) => q.code == 'METAL').price, 4);
      expect(quotes.singleWhere((q) => q.code == 'MAYOREO:archivo').price, 3);
      expect(quotes.singleWhere((q) => q.code == 'MAYOREO:revuelto').price, 1);
      final pallet = quotes.singleWhere((q) => q.code == 'MAYOREO:tarima');
      expect(pallet.price, isNull);
      expect(pallet.unit, 'pzas');
    },
  );
  test(
    'weekly ledger carries balances, includes empty weeks and ignores internal cuts',
    () {
      final p = project(
        data(
          movements: [
            movement(-21, 40000000),
            movement(-20, -5000000),
            movement(-7, -10000000),
            movement(-6, 0, concept: 'corteInterno'),
            movement(0, -2000000),
            movement(1, -3000000),
            movement(-10, -9000000, projected: true),
          ],
        ),
      );
      expect(p.balance, 23000000);
      expect(p.history.map((w) => w.closing), [
        35000000,
        35000000,
        25000000,
        23000000,
      ]);
      expect(p.projectedBalance, 20000000);
      expect(p.events.single.date, day(1));
    },
  );
  test(
    'uses first receipt, excludes later shipments, overdue and cancelled',
    () {
      final p = project(
        data(
          receipt: 4,
          fiscal: 2,
          movements: [movement(-7, 40000000)],
          shipments: [
            shipment('ok', 1),
            shipment('late', 3),
            shipment('old', -1),
            shipment('cancel', 0, status: 'cancelado'),
          ],
        ),
      );
      expect(p.deadline, day(2));
      expect(p.projectedBalance, 33000000);
      expect(p.events, hasLength(1));
      expect(p.needs.single.amount, 33000000);
      expect(p.needs.single.sendBy, day(2));
      expect(
        p.quotes['PACA_NACIONAL']!.quantityFor(p.needs.single.amount),
        189,
      );
      expect(p.warnings.join(' '), contains('vencidos'));
      expect(p.warnings.join(' '), contains('posteriores'));
    },
  );
  test(
    'applied sale is counted once, including explicit link across weeks',
    () {
      final source = data(
        movements: [
          movement(-14, 40000000),
          movement(0, -8400000, report: 'r1'),
        ],
        shipments: [shipment('linked', -7, status: 'embarcado')],
        sales: [f.incomeSale(client: 'EL PALOMAR', day: -6)],
        links: {'linked': 'r1'},
      );
      final p = project(source);
      expect(p.balance, 31600000);
      expect(p.projectedBalance, 31600000);
      expect(p.events, isEmpty);
      expect(source.palomarCoverageShipments.single.plannedQuantity, 40);
    },
  );
  test(
    'future posting replaces shipment once; after-deadline posting cannot cover early receipt',
    () {
      for (final date in [1, 4]) {
        final p = project(
          data(
            receipt: 2,
            movements: [
              movement(-7, 40000000),
              movement(date, -8400000, report: 'r1'),
            ],
            shipments: [shipment('linked', 0)],
            sales: [f.incomeSale(client: 'EL PALOMAR')],
            links: {'linked': 'r1'},
          ),
        );
        expect(p.projectedBalance, date == 1 ? 31600000 : 40000000);
        expect(p.events.length, date == 1 ? 1 : 0);
      }
    },
  );
  test(
    'unapplied delivered value remains a forecast and never rewrites historical balance',
    () {
      final p = project(
        data(
          movements: [movement(-7, 40000000)],
          shipments: [shipment('pending', -2, status: 'embarcado')],
          sales: [f.incomeSale(client: 'EL PALOMAR', day: -2)],
        ),
      );
      expect(p.balance, 40000000);
      expect(p.projectedBalance, 31600000);
      expect(p.events.single.description, contains('pendiente de aplicar'));
      expect(p.events.single.date, day(0));
    },
  );
  test(
    'ambiguous sale or unlinked remittance blocks coverage without a second credit',
    () {
      for (final withSale in [true, false]) {
        final p = project(
          data(
            movements: [
              movement(-7, 40000000),
              if (!withSale) movement(0, -8400000),
            ],
            shipments: [shipment('a', 0), if (withSale) shipment('b', 0)],
            sales: [if (withSale) f.incomeSale(client: 'EL PALOMAR')],
          ),
        );
        expect(p.complete, false);
        expect(p.events.every((e) => e.signedCents == null), true);
        expect(p.needs, isEmpty);
      }
    },
  );
  test(
    'missing valuation does not falsely mark coverage complete or invent bales',
    () {
      final p = project(
        data(
          movements: [movement(-7, 40000000)],
          shipments: [shipment('s', 0)],
          materials: [],
        ),
      );
      expect(p.complete, false);
      expect(p.events.single.signedCents, isNull);
      expect(p.needs, isEmpty);
      expect(p.selectableMaterials, isEmpty);
      final noShipment = project(
        data(movements: [movement(-7, 40000000)], materials: []),
      );
      expect(noShipment.sends(null).single.quantity, isNull);
    },
  );
  test(
    'additional amount belongs to selected week and preserves every cent',
    () {
      final p = project(
        data(
          movements: [movement(-30, 40000001)],
          prices: {'EL PALOMAR|PACA_NACIONAL': 3},
        ),
        now: -14,
      );
      expect(p.needs.map((w) => w.sendBy), [day(4)]);
      expect(p.needs.map((w) => w.amount).reduce((a, b) => a + b), 40000001);
      expect(p.quotes['PACA_NACIONAL']!.price, 2100);
      for (final n in p.needs) {
        expect(
          p.quotes['PACA_NACIONAL']!.amount(
            p.quotes['PACA_NACIONAL']!.quantityFor(n.amount)!,
          )!,
          greaterThanOrEqualTo(n.amount),
        );
      }
    },
  );
  test(
    'no date shows history only; past date is an actual historical cutoff',
    () {
      final p = project(
        data(
          receipt: null,
          movements: [movement(-7, 40000000)],
          shipments: [shipment('s', 0)],
        ),
      );
      expect(p.deadline, isNull);
      expect(p.needs, isEmpty);
      expect(p.events, isEmpty);
      final old = project(
        data(
          receipt: 2,
          movements: [movement(-7, 40000000), movement(3, -40000000)],
          shipments: [shipment('s', 1)],
        ),
        now: 7,
      );
      expect(old.cutoff, day(2));
      expect(old.balance, 40000000);
      expect(old.needs, isEmpty);
      expect(old.events, isEmpty);
    },
  );
  test(
    'Sunday deadline has no invented Sunday shipping and covered balance requires no extra',
    () {
      final p = project(data(receipt: 6, movements: [movement(-7, 40000000)]));
      expect(p.needs.single.sendBy, day(5));
      final sunday = project(
        data(receipt: 6, movements: [movement(-7, 40000000)]),
        now: 6,
      );
      expect(sunday.needs, isEmpty);
      expect(sunday.warnings.single, contains('No quedan días'));
      final covered = project(
        data(movements: [movement(-7, 1000000)], shipments: [shipment('a', 0)]),
      );
      expect(covered.remaining, 0);
      expect(covered.needs, isEmpty);
    },
  );
  test(
    'repository adapter values and reconciles a non-carton sale with its applied remittance',
    () {
      final tables = List.generate(18, (_) => <Map<String, dynamic>>[]);
      tables[1] = [f.incomeClients.last.toJson()];
      tables[2] = [
        {'id': 'p', 'name': 'EL PALOMAR', 'is_active': true},
      ];
      tables[3] = [
        {
          'company_id': 'p',
          'material_id': 'metal',
          'is_active': true,
          'final_price': 5,
        },
      ];
      tables[4] = [
        {
          'id': 'metal',
          'code': 'METAL',
          'name': 'METAL',
          'unit': 'KG',
          'is_active': true,
        },
      ];
      tables[7] = [
        {
          'id': 'r',
          'material_id': 'metal',
          'sale_date': '2026-09-21',
          'client_name_snapshot': 'EL PALOMAR',
          'ticket': 'M-1',
          'approved_weight': 1000,
          'approved_price': 5,
          'approved_amount': 5000,
        },
      ];
      tables[10] = [
        {
          'id': 'check',
          'type': 'chequeLiberado',
          'date': '2026-09-14',
          'amount': 10000,
        },
        {
          'id': 'applied',
          'type': 'remisionAplicada',
          'date': '2026-09-21',
          'amount': 5000,
          'source_report_id': 'r',
        },
      ];
      tables[16] = [
        {
          'week_start': '2026-09-21',
          'cash_date': '2026-09-25',
          'fiscal_date': null,
          'revision': 1,
        },
      ];
      tables[17] = [
        {
          'id': 'metal-plan',
          'ship_date': '2026-09-21',
          'client_name': 'EL PALOMAR',
          'planning_material_code': 'METAL',
          'quantity_unit': 'KG',
          'planned_units': 1000,
          'status': 'confirmado',
        },
      ];
      final assembled = assembleExpectedIncomeData(
        bundle: f.incomeBundle(shipments: []),
        today: day(0),
        tables: tables,
      );
      expect(assembled.sales.single.material, 'METAL');
      expect(assembled.sales.single.approvedCents, 500000);
      final p = project(assembled);
      expect(p.balance, 500000);
      expect(p.projectedBalance, 500000);
      expect(p.events, isEmpty);
      final send = p.sends('METAL').single;
      expect(send.quantity, 1000);
      expect(send.unit, 'kg');
      expect(send.amount, 500000);
      expect(p.balanceWithSends('METAL'), 0);
    },
  );
  test('source adapter retains all-week links and coverage shipments', () {
    final tables = List.generate(18, (_) => <Map<String, dynamic>>[]);
    tables[6] = [
      {'shipment_id': 'prior', 'sale_report_id': 'r1'},
    ];
    tables[17] = [
      {
        'id': 'prior',
        'ship_date': '2026-09-14',
        'client_name': 'EL PALOMAR',
        'planning_material_code': 'PACA_NACIONAL',
        'quantity_unit': 'PACAS',
        'planned_units': 40,
        'status': 'confirmado',
      },
    ];
    final assembled = assembleExpectedIncomeData(
      bundle: f.incomeBundle(shipments: []),
      today: day(0),
      tables: tables,
    );
    expect(assembled.palomarCoverageLinks, {'prior': 'r1'});
    expect(assembled.palomarCoverageShipments.single.id, 'prior');
    expect(assembled.links, isEmpty);
  });
  testWidgets(
    'informational table shows one weekly row per material without ledger or daily detail',
    (tester) async {
      for (final family in ['Roboto', 'Ahem']) {
        await (FontLoader(family)..addFont(
              Future.value(
                ByteData.sublistView(
                  File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync(),
                ),
              ),
            ))
            .load();
      }
      await tester.binding.setSurfaceSize(const Size(1200, 680));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: v.app(
            SingleChildScrollView(
              child: PalomarCoverageView(
                data: data(
                  materials: [],
                  movements: [
                    movement(-1, -1656914),
                    movement(0, 51656940),
                    movement(4, -31100026, projected: true),
                  ],
                  shipments: [
                    shipment('next', -7),
                    shipment('this', 1),
                    bulkShipment('metal', 'METAL', 1000, 2),
                  ],
                  quotes: [
                    ...d.dispatchQuotes,
                    const PalomarMaterialQuote('METAL', 'Metal', 'kg', 5),
                  ],
                  sales: [
                    for (var i = 0; i < 5; i++)
                      d.dispatchSale(i, -7 + i, (i + 1) * 100000),
                  ],
                ),
                bundle: f.incomeBundle(shipments: []),
                now: day(0),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Material por enviar esta semana'), findsOneWidget);
      expect(
        find.text(r'Saldo real por cubrir: $500,000.26 · al 2026-09-25'),
        findsOneWidget,
      );
      for (final label in [
        'Limpio (Ordinario de primera)',
        'Rebaba',
        'Mixto',
        'Retorno industrial',
        'Pesado',
        'TOTAL SEMANAL',
        'Material',
        'Cantidad por enviar',
        'Importe estimado',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('16,667 kg'), findsOneWidget);
      expect(find.text(r'$33,334.00'), findsOneWidget);
      expect(find.text('118,336 kg'), findsOneWidget);
      expect(find.text(r'$500,010.00'), findsOneWidget);
      expect(find.textContaining('valuación de la agenda'), findsNothing);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      for (final removed in [
        'Histórico semanal de la cuenta',
        'Día / fecha',
        'Envíos de la agenda considerados para cubrir la cuenta',
        'Saldo con la propuesta',
      ]) {
        expect(find.text(removed), findsNothing);
      }
      expect(tester.takeException(), isNull);
      if (Platform.environment['DICSA_PALOMAR_COVERAGE_QA'] == '1') {
        await tester.runAsync(() async {
          final picture =
              await (capture.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final png = await picture.toByteData(format: ui.ImageByteFormat.png);
          File(
            '/private/tmp/dicsa-palomar-coverage.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
          picture.dispose();
        });
      }
      await tester.binding.setSurfaceSize(const Size(650, 950));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Cantidad por enviar'), findsOneWidget);
      expect(find.text(r'$500,010.00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
