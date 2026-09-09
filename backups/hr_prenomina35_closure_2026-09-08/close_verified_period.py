from pathlib import Path
import json,sys,urllib.request,urllib.parse,datetime,hashlib,base64,shutil

folder=Path('/private/tmp/dicsa_prenomina35_close')
backup=Path('/Users/martinvelzat/DICSA/apps/dicsa_operacion/backups/hr_prenomina35_closure_2026-09-08')
read=lambda name:json.loads((folder/name).read_text())
source=read('prewrite_source.json');stored=read('persisted_published.json')
verification=read('persisted_financial_verification.json');manifest=read('closing_manifest.json')
assert verification['passed'] is True and verification['prenomina_nomina_receipts_equal'] is True
assert verification['sha256']==hashlib.sha256((folder/'persisted_published.json').read_bytes()).hexdigest()
assert verification['period']==source['period']
assert verification['totals']==manifest['planned_totals']
assert len(stored)==78 and all(r['draft_status']=='publicado' and r['period_label']==source['period'] for r in stored)
assert not (folder/'closure_saved.json').exists(),'Closure already recorded; verify before resuming'
sys.path.insert(0,'/Users/martinvelzat/DICSA/apps/dicsa_operacion/tool')
import audit_finanzas_company_identities as api
token=api.resolve_supabase_bearer_token()
segment=token.split('.')[1]
user_id=json.loads(base64.urlsafe_b64decode(segment+'='*(-len(segment)%4)))['sub']
headers={'apikey':api.SUPABASE_ANON_KEY,'Authorization':'Bearer '+token}
def call(table,params,method='GET',data=None):
    req=urllib.request.Request(api.SUPABASE_URL+'/rest/v1/'+table+'?'+urllib.parse.urlencode(params),
        method=method,data=None if data is None else json.dumps(data,ensure_ascii=False).encode(),
        headers={**headers,**({'Content-Type':'application/json','Prefer':'return=representation'} if data is not None else {})})
    with urllib.request.urlopen(req,timeout=40) as response:return json.load(response)
def save(name,value):
    p=folder/name;p.write_text(json.dumps(value,ensure_ascii=False,indent=2));p.chmod(0o600)
    shutil.copy2(p,backup/name);(backup/name).chmod(0o600)
canonical=lambda rows:sorted(json.dumps(r,sort_keys=True,ensure_ascii=False) for r in rows)
params={'select':'*','period_label':'eq.'+source['period']}
assert canonical(call('hr_prenomina_draft_rows',params))==canonical(stored),'Concurrent payroll edit'
assert not call('hr_payroll_period_closures',params),'A closure already exists'
assert canonical(call('hr_employee_event_period_impacts',params))==canonical(source['impacts']),'Operational impacts changed'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
snapshot={
    'period_label':source['period'],'published_rows':78,'employees_expected':78,'closed_at':now,
    'totals':verification['totals'],'flow_total':53067.24,
    'source_reference':'NOMINA35.xlsx','excel_cash_total_original':59208.48,
    'excel_cash_total_completed':78741.44,'cash_difference_documented':163.20,
    'difference_reasons':{'gabriel_manual_overtime':163.0,'net_rounding':0.20},
    'confirmed_rh_adjustments':manifest['approved_adjustments'],
    'official_contpaq_fiscal_preserved':True,'period_only':True,
    'financial_verification_sha256':verification['sha256'],
}
payload={'period_label':source['period'],'status':'cerrado','closed_at':now,'closed_by':user_id,
    'notes':'Cierre del periodo 35 confirmado por el usuario. Cinco ajustes RH conciliados contra NOMINA35.xlsx. Diferencia de efectivo documentada: $163.00 de horas extra manuales de Gabriel y $0.20 netos de centavos. CONTPAQ y salarios vigentes conservados. Rebeca $0; Javier $4,900.',
    'summary_snapshot':snapshot}
save('pending_closure_payload.json',payload)
result=call('hr_payroll_period_closures',{'select':'*'},method='POST',data=payload)
assert len(result)==1 and result[0]['status']=='cerrado'
for k,v in payload.items():
    if k!='closed_at':assert result[0][k]==v
save('closure_saved.json',result[0])
closed=call('hr_payroll_period_closures',params)
assert len(closed)==1 and closed[0]==result[0]
final=call('hr_prenomina_draft_rows',params)
assert canonical(final)==canonical(stored),'Amounts changed during closure'
save('final_closed_drafts.json',final)
save('final_verification.json',{
    'period':source['period'],'status':'cerrado','closed_at':closed[0]['closed_at'],
    'published_rows':78,'financial_totals':verification['totals'],
    'flow_total':53067.24,'rh_adjustments_applied':5,'net_adjustment':879.56,
    'publication_and_close_verified':True,'nomina_receipt_projection_verified':True,
    'period37_modified':False,'receipts_emitted':False,
})
print(json.dumps({'status':'cerrado','published':78,'fiscal':148725.80,'deposit':122888.40,'cheque':25837.40,'flow':53067.24,'cash_envelopes':78904.64,'total':201793.04}))
