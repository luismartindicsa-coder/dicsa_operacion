import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dicsa_operacion/app/hr/human_resources_prenomina_page.dart';
import 'package:dicsa_operacion/app/hr/human_resources_nomina_page.dart';
import 'package:dicsa_operacion/app/hr/human_resources_attendance_source.dart';

void main() {
  test('persisted period 35 publications agree with approved amounts and receipts', () {
    const folder='/private/tmp/dicsa_prenomina35_close';
    dynamic read(String name)=>jsonDecode(File('$folder/$name.json').readAsStringSync());
    List<Map<String,dynamic>> maps(dynamic value)=>(value as List).map((r)=>Map<String,dynamic>.from(r as Map)).toList();
    final source=read('prewrite_source') as Map;
    final saved=maps(read('persisted_published'));
    final expected={for(final r in maps(read('five_rh_adjustments_reopened')))r['id']:r};
    expect(saved.length,78);
    expect(saved.map((r)=>r['employee_id']).toSet().length,78);
    for(final r in saved) {
      expect(r['draft_status'],'publicado');
      expect(r['period_label'],source['period']);
    }
    final rows=hrPrenominaPeriodProjectionForTesting(
      period:source['period'],employees:maps(source['employees']),
      contpaq:maps(source['imports'][0]['entries']),
      attendance:maps(source['attendance']).where(isHrOperationalAttendanceRow).toList(),
      vacations:maps(source['vacations']),permissions:maps(source['permissions']),
      impacts:maps(source['impacts']),drafts:saved,
    );
    final nomina=hrNominaFiscalTotalsForTesting(drafts:saved,period:source['period'],closed:true);
    final nominaById={for(final r in maps(nomina['rows']))r['id']:r};
    for(final r in rows) {
      final prior=expected[r['id']]!;
      for(final key in ['fiscal','fiscal_deposit','fiscal_cash','envelope','total']) {
        expect(r[key],closeTo((prior[key] as num).toDouble(),0.001),reason:'Persisted ${r['id']} $key');
      }
      final n=nominaById[r['id']]!;
      for(final pair in [('fiscal','fiscal'),('deposit','fiscal_deposit'),('cheque','fiscal_cash'),('total','total')]) {
        expect(n[pair.$1],closeTo((r[pair.$2] as num).toDouble(),0.001),reason:'Nomina ${r['id']} ${pair.$1}');
      }
      final receipt=hrNominaOfficialNetForTesting(saved.singleWhere((d)=>d['employee_id']==r['id']));
      expect(receipt['receipt_total'],closeTo((r['total'] as num).toDouble(),0.001),reason:'Receipt ${r['id']}');
      expect((r['fiscal_deposit'] as num)+(r['envelope'] as num),closeTo((r['total'] as num).toDouble(),0.001));
    }
    final totals={for(final key in ['fiscal','fiscal_deposit','fiscal_cash','envelope','total'])
      key:(rows.fold<double>(0,(sum,r)=>sum+(r[key] as num).toDouble())*100).round()/100};
    expect(totals,{'fiscal':148725.80,'fiscal_deposit':122888.40,'fiscal_cash':25837.40,'envelope':78904.64,'total':201793.04});
    for(final a in {'132':945.12,'217':249.48,'298':-315.04,'153':-24.20,'157':24.20}.entries) {
      final r=saved.singleWhere((r)=>r['employee_id']==a.key);
      expect(r['manual_adjustment_amount'],a.value);
      expect(r['source_snapshot']['period35_excel_rh_adjustment']['confirmed_by_user'],true);
    }
    expect(rows.singleWhere((r)=>r['id']=='8')['total'],0);
    expect(rows.singleWhere((r)=>r['id']=='135')['total'],4900);
    File('$folder/persisted_financial_verification.json').writeAsStringSync(jsonEncode({
      'passed':true,'period':source['period'],'published':78,'totals':totals,
      'sha256':sha256.convert(File('$folder/persisted_published.json').readAsBytesSync()).toString(),
      'prenomina_nomina_receipts_equal':true,
    }));
    File('$folder/final_projected_rows.json').writeAsStringSync(jsonEncode(rows));
    File('$folder/final_nomina_rows.json').writeAsStringSync(jsonEncode(nomina));
  });
}
