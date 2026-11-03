import 'dart:convert';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_models.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_repository.dart';
import 'package:http/http.dart' as http;

Map<String, List<StatementRow>> accountingFixture({bool dense = false}) {
  StatementRow sale(String id, String date, double amount) => {
    'id': id,
    'sale_date': date,
    'ticket': id,
    'material_id': 's',
    'approved_weight': 100,
    'approved_price': amount / 100,
    'approved_amount': amount,
  };
  StatementRow retail(
    String id,
    String date,
    double amount,
    String direction,
  ) => {
    'id': id,
    'ticket_date': date,
    'ticket_number': id,
    'commercial_material_id': 'r',
    'amount_total': amount,
    'net_weight': 100,
    'direction': direction,
    'status': 'PAGADO',
  };
  StatementRow invoice(String id, String date, double amount) => {
    'id': id,
    'invoice_date': date,
    'total_amount': amount,
  };
  StatementRow market(String id, String date, String flow, double amount) => {
    'source_event_id': id,
    'source_area': 'menudeo',
    'channel': 'menudeo',
    'event_at': date,
    'flow': flow,
    'general_material_key': 'CARTON',
    'general_material_label': 'Cartón',
    'volume_kg': 100,
    'amount_total': amount,
  };
  final currentInvoice = invoice('expense', '2026-09-15', 130),
      priorInvoice = invoice('prior-expense', '2026-09-08', 40);
  final other = {
    'id': 'other',
    'movement_date': '2026-09-15',
    'credit_amount': 10,
    'debit_amount': 0,
  };
  final data = <String, List<StatementRow>>{
    for (final spec in statementSourceSpecs) spec.table: [],
    'accounting_statement_closures': [],
    'accounting_statement_reviews': [],
    'profiles': [],
    'mayoreo_sales_reports': dense
        ? [for (var i = 0; i < 1005; i++) sale('s$i', '2026-09-15', 2)]
        : [sale('sale', '2026-09-15', 1000), sale('prior', '2026-09-08', 800)],
    'mayoreo_accounts': [
      {'id': 'sale', 'status': 'approved'},
      {'id': 'prior', 'status': 'approved'},
    ],
    'men_tickets': dense
        ? []
        : [
            retail('r1', '2026-09-15', 200, 'OUT'),
            retail('r2', '2026-09-08', 110, 'OUT'),
            retail('p1', '2026-09-15', 350, 'IN'),
            retail('p2', '2026-09-08', 250, 'IN'),
          ],
    'material_general_catalog_v2': [
      {'id': 'g', 'name': 'Cartón'},
    ],
    'mayoreo_material_catalog': [
      {'id': 's', 'general_material_id': 'g'},
    ],
    'material_commercial_catalog_v2': [
      {'id': 'r', 'general_material_id': 'g'},
    ],
    'inventory_movements_v2': dense
        ? []
        : [
            for (final day in ['2026-09-15', '2026-09-08'])
              {
                'id': day,
                'op_date': day,
                'flow': 'OUT',
                'inventory_level': 'COMMERCIAL',
                'origin_type': 'SALE',
                'general_material_id': 'g',
                'net_kg': 100,
              },
          ],
    'finanzas_supplier_invoices': dense ? [] : [currentInvoice, priorInvoice],
    'finanzas_bank_movements': dense
        ? [
            for (var i = 0; i < 1005; i++)
              {
                'id': 'b$i',
                'movement_date': '2026-09-15',
                'credit_amount': 2,
                'debit_amount': 0,
              },
          ]
        : [
            {
              'id': 'receipt',
              'movement_date': '2026-09-15',
              'credit_amount': 1000,
              'debit_amount': 0,
              'linked_external_ref': 'sale',
            },
            {
              'id': 'loan',
              'movement_date': '2026-09-15',
              'credit_amount': 500,
              'debit_amount': 0,
              'reference': 'PRESTAMO',
            },
            other,
          ],
    'direction_vault_vouchers': dense
        ? [
            for (var i = 0; i < 1005; i++)
              {
                'id': 'v$i',
                'voucher_date': '2026-09-15',
                'voucher_type': 'deposit',
                'total_amount': i == 0 ? 501 : 1,
              },
          ]
        : [
            {
              'id': 'v',
              'voucher_date': '2026-09-15',
              'voucher_type': 'deposit',
              'total_amount': 20,
            },
          ],
    'direction_vault_voucher_lines': dense
        ? [
            for (var i = 0; i < 1005; i++)
              for (var j = 0; j < (i == 0 ? 501 : 1); j++)
                {'id': 'v$i-$j', 'voucher_id': 'v$i', 'amount': 1},
          ]
        : [
            {'id': 'vl', 'voucher_id': 'v', 'amount': 20},
          ],
    'v_commercial_market_events': dense
        ? [
            for (var i = 0; i < 1005; i++)
              market('e$i', '2026-09-15', 'purchase', 1),
          ]
        : [
            market('buy', '2026-09-15', 'purchase', 500),
            market('sell', '2026-09-15', 'sale', 900),
            market('oldbuy', '2026-09-08', 'purchase', 300),
            market('oldsell', '2026-09-08', 'sale', 700),
          ],
  };
  if (!dense) {
    data['accounting_statement_reviews'] = [
      for (final r in [currentInvoice, priorInvoice])
        StatementDecision(
          id: 'invoice:${r['id']}',
          signature: stSignature([r, []]),
          note: 'Gasto devengado sin IVA conciliado',
          account: StatementAccount.operating,
          amount: stNumber(r['total_amount']),
          revision: 1,
        ).toRow()..['revision'] = 1,
      StatementDecision(
        id: 'bank:other',
        signature: stSignature(other),
        note: 'Interés ganado comprobado',
        account: StatementAccount.otherIncome,
        amount: 10,
        revision: 1,
      ).toRow()..['revision'] = 1,
    ];
  }
  return data;
}

http.Response accountingResponse(
  http.Request r,
  Map<String, List<StatementRow>> data,
) {
  final table = r.url.pathSegments.last;
  Object body;
  if (table == 'accounting_statement_can_read' ||
      table == 'accounting_statement_can_manage') {
    body = true;
  } else {
    if (!data.containsKey(table)) {
      throw StateError('Unexpected accounting source: $table');
    }
    final rows = data[table]!;
    final offset = int.tryParse(r.url.queryParameters['offset'] ?? '') ?? 0;
    final limit =
        int.tryParse(r.url.queryParameters['limit'] ?? '') ?? rows.length;
    body = rows.skip(offset).take(limit).toList();
  }
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
    request: r,
  );
}
