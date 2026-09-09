from pathlib import Path
import json,sys,urllib.request,urllib.parse,datetime,shutil

folder=Path('/private/tmp/dicsa_prenomina35_close')
backup=Path('/Users/martinvelzat/DICSA/apps/dicsa_operacion/backups/hr_prenomina35_closure_2026-09-08')
read=lambda name:json.loads((folder/name).read_text())
source=read('prewrite_source.json');plan=read('confirmed_publication_plan.json')
manifest=read('closing_manifest.json')
assert manifest['user_confirmed_five_adjustments'] is True
assert not (folder/'publication_operations.json').exists(),'Existing operation log; inspect before resuming'
assert len(plan)==78 and all(r['period_label']==source['period'] and r['draft_status']=='publicado' for r in plan)
assert all(not r['impact_prenomina'] or r['payroll_settlement_status']=='liquidado' or r['prenomina_sync_status']=='omitido' for r in source['impacts'])
for table in ['vacations','permissions']:
    assert not any(r['attendance_period_label']==source['period'] and r['impact_prenomina'] and r['status']!='cancelado' and r['prenomina_sync_status']!='aplicado' for r in source[table]),'Pending operational event'
sys.path.insert(0,'/Users/martinvelzat/DICSA/apps/dicsa_operacion/tool')
import audit_finanzas_company_identities as api
headers={'apikey':api.SUPABASE_ANON_KEY,'Authorization':'Bearer '+api.resolve_supabase_bearer_token()}
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
assert not call('hr_payroll_period_closures',params),'Period already has a closure'
assert canonical(call('hr_prenomina_draft_rows',params))==canonical(source['drafts']),'Concurrent change'
before={r['employee_id']:r for r in source['drafts']}
operations=[]
for row in plan:
    employee_id=row['employee_id']
    prior=before.get(employee_id)
    if not prior or prior['draft_status']=='publicado':continue
    changed={k:v for k,v in row.items() if k not in ['id','created_at','updated_at'] and prior.get(k)!=v}
    result=call('hr_prenomina_draft_rows',{
        'select':'*','id':'eq.'+prior['id'],'employee_id':'eq.'+employee_id,
        'period_label':'eq.'+source['period'],'updated_at':'eq.'+prior['updated_at'],
        'draft_status':'eq.'+prior['draft_status'],
    },method='PATCH',data=changed)
    assert len(result)==1,'Concurrent edit: '+employee_id
    for key,value in prior.items():
        if key not in changed and key!='updated_at':assert result[0][key]==value,'Unexpected mutation: '+key
    for key,value in changed.items():assert result[0][key]==value
    operations.append({'employee_id':employee_id,'kind':'publish_existing','before':prior,'after':result[0]})
    save('publication_operations.json',operations)
    if len(operations)%10==0:print(json.dumps({'existing_published':len(operations)}),flush=True)
inserts=[{k:v for k,v in r.items() if k not in ['id','created_at','updated_at']} for r in plan if r['employee_id'] not in before]
assert len(inserts)==40
save('pending_insert_batch.json',inserts)
created=call('hr_prenomina_draft_rows',{'select':'*'},method='POST',data=inserts)
assert len(created)==len(inserts)
created_by_id={r['employee_id']:r for r in created}
for row in inserts:
    actual=created_by_id[row['employee_id']]
    for key,value in row.items():assert actual[key]==value
    operations.append({'employee_id':row['employee_id'],'kind':'create_published','before':None,'after':actual})
save('publication_operations.json',operations)
persisted=call('hr_prenomina_draft_rows',params)
assert len(persisted)==78 and all(r['draft_status']=='publicado' for r in persisted)
actual_by_id={r['employee_id']:r for r in persisted}
for row in plan:
    actual=actual_by_id[row['employee_id']]
    for key,value in row.items():assert actual[key]==value,'Persisted mismatch '+row['employee_id']+' '+key
assert actual_by_id['8']==before['8'],'Rebeca must remain unchanged'
save('persisted_published.json',persisted)
save('publication_result.json',{'period':source['period'],'verified_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'adjustments_applied':5,'published_existing':37,'created_published':40,'previously_published_preserved':1,
    'total_published':78,'period_closed':False,'only_period35_mutated':True})
print(json.dumps({'published':78,'adjustments_applied':5,'closed':False}))
