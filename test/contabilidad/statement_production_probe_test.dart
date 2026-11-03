import 'dart:convert';
import 'dart:io';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_models.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_engine.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_expense_coverage.dart';
import 'package:dicsa_operacion/app/contabilidad/contabilidad_income_statement_store.dart';
import 'package:dicsa_operacion/app/contabilidad/contabilidad_pdf_export.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/contabilidad/statement/statement_review_topics.dart';

void main() {
  test(
    'analyze authorized read-only snapshot and render statement',
    () async {
      final root = Platform.environment['DICSA_ACCOUNTING_SNAPSHOT']!;
      final tables = <String, List<StatementRow>>{};
      for (final f in Directory('$root/raw').listSync().whereType<File>()) {
        if (!f.path.endsWith('.json')) continue;
        tables[f.uri.pathSegments.last.replaceAll(
          '.json',
          '',
        )] = (jsonDecode(f.readAsStringSync()) as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
      }
      final a = analyzeStatement(
        StatementBundle(
          period: StatementPeriod(
            DateTime(2026, 10, 1),
            DateTime(2026, 10, 31),
          ),
          tables: tables,
        ),
      );
      final output = {
        ...a.toSnapshot(),
        'status': a.status,
        'automatic_count': a.automaticCount,
        'included_pending_amount': a.pending
            .where((e) => e.includedPending)
            .fold<double>(0, (s, e) => s + e.amount),
        'review_topics': {
          for (final t in statementReviewTopics(a).entries)
            t.key.label: t.value.length,
        },
        'warnings': a.warnings,
        'totals': {for (final x in StatementAccount.values) x.name: a.total(x)},
        'expense_coverage': [
          for (final r in statementExpenseCoverage(a))
            {
              'source': r.source,
              'category': r.category,
              'count': r.count,
              'recorded': r.recorded,
              'recognized_here': r.recognizedHere,
              'pending': r.pending,
              'linked': r.linked,
              'linked_pending': r.linkedPending,
              'ids': r.ids,
            },
        ],
      };
      await File(
        '$root/resultado_octubre.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(output));
      final bytes = await buildContabilidadIncomeStatementPdf(
        statement: statementDatasetFromAnalysis(a),
      );
      await File('$root/estado_resultados_octubre.pdf').writeAsBytes(bytes);
      expect(bytes.take(4), [37, 80, 68, 70]);
      expect(a.complete, isFalse);
      expect(
        a.entries
            .singleWhere((e) => e.fact.id == 'conversion:confirmed-bianca-160')
            .amount,
        6000,
      );
      // ignore: avoid_print
      print(
        'Production snapshot: ${a.entries.length} operations, ${a.pending.length} pending, status ${a.status}',
      );
    },
    skip: Platform.environment['DICSA_ACCOUNTING_SNAPSHOT'] == null,
  );
}
