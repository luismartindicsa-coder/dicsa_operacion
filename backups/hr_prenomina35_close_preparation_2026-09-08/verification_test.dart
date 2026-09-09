import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:dicsa_operacion/app/hr/human_resources_nomina_page.dart';
import 'package:dicsa_operacion/app/hr/human_resources_attendance_source.dart';

void main() {
  const folder = '/private/tmp/dicsa_prenomina35_close';
  final source = jsonDecode(File('$folder/app_source.json').readAsStringSync()) as Map;
  List<Map<String,dynamic>> maps(dynamic value) => (value as List).map((r) => Map<String,dynamic>.from(r as Map)).toList();
  final stored = maps(source['drafts']);
  final original = {for (final r in stored) r['employee_id']: r};
  List<Map<String,dynamic>> project(List<Map<String,dynamic>> drafts) => hrPrenominaPeriodProjectionForTesting(
    period: source['period'], employees: maps(source['employees']),
    contpaq: maps(source['imports'][0]['entries']),
    attendance: maps(source['attendance']).where(isHrOperationalAttendanceRow).toList(),
    vacations: maps(source['vacations']), permissions: maps(source['permissions']),
    impacts: maps(source['impacts']), drafts: drafts,
  );
  void write(String name,dynamic value) => File('$folder/$name.json').writeAsStringSync(jsonEncode(value));
  Map<String,double> totals(List<Map<String,dynamic>> rows) => {
    for (final key in ['fiscal','fiscal_deposit','fiscal_cash','envelope','total'])
      key: (rows.fold<double>(0,(sum,r)=>sum+(r[key] as num).toDouble())*100).round()/100,
  };
  for (final scenario in ['current','five_rh_adjustments']) {
    test('period 35 $scenario preserves amounts through publication, Nomina and receipt', () {
      final before = project(stored);
      expect(before.length,78);
      expect(totals(before),{
        'fiscal':148725.80,'fiscal_deposit':122888.40,
        'fiscal_cash':25837.40,'envelope':78025.08,'total':200913.48,
      });
      final candidate = <Map<String,dynamic>>[];
      const adjustments = {'132':945.12,'217':249.48,'298':-315.04,'153':-24.20,'157':24.20};
      for (final r in before) {
        final old=original[r['id']];
        if(old?['draft_status']=='publicado') {
          candidate.add(Map<String,dynamic>.from(old!));
          continue;
        }
        final payload=Map<String,dynamic>.from(r['payload'] as Map);
        if(scenario=='five_rh_adjustments' && adjustments.containsKey(r['id'])) {
          expect(payload['manual_adjustment_amount']??0,0);
          payload['manual_adjustment_amount']=adjustments[r['id']];
        }
        candidate.add(payload);
      }
      final projected = project(candidate);
      final published = [for(final r in candidate) {...r,'draft_status':'publicado'}];
      final reopened = project(published);
      final byId={for(final r in projected)r['id']:r};
      write('${scenario}_candidate',candidate);
      write('${scenario}_published',published);
      write('${scenario}_before',projected);
      write('${scenario}_reopened',reopened);
      for(final r in reopened) {
        for(final key in ['fiscal','fiscal_deposit','fiscal_cash','envelope','total']) {
          expect(r[key],closeTo((byId[r['id']]![key] as num).toDouble(),0.001),reason:'Publish ${r['id']} $key');
        }
        expect((r['fiscal_deposit'] as num)+(r['envelope'] as num),closeTo((r['total'] as num).toDouble(),0.001),reason:'Payment split ${r['id']}');
      }
      final nomina=hrNominaFiscalTotalsForTesting(drafts:published,period:source['period'],closed:true);
      write('${scenario}_nomina',nomina);
      for(final r in maps(nomina['rows'])) {
        final expected=byId[r['id']]!;
        for(final pair in [('fiscal','fiscal'),('deposit','fiscal_deposit'),('cheque','fiscal_cash'),('total','total')]) {
          expect(r[pair.$1],closeTo((expected[pair.$2] as num).toDouble(),0.001),reason:'Nomina ${r['id']} ${pair.$1}');
        }
        final receipt=hrNominaOfficialNetForTesting(published.singleWhere((d)=>d['employee_id']==r['id']));
        expect(receipt['receipt_total'],closeTo((expected['total'] as num).toDouble(),0.001),reason:'Receipt ${r['id']}');
      }
      final total=totals(reopened);
      expect(total['total'],scenario=='current'?200913.48:201793.04);
      expect(total['fiscal'],148725.80);
      expect(byId['8']!['total'],0);
      expect(byId['135']!['total'],4900);
      write('${scenario}_totals',total);
    });
  }
}
