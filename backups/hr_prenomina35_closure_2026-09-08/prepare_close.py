from pathlib import Path
import datetime,json,shutil,hashlib

folder=Path('/private/tmp/dicsa_prenomina35_close')
read=lambda name:json.loads((folder/name).read_text())
source=read('app_source.json');fresh=read('prewrite_source.json')
canonical=lambda rows:sorted(json.dumps(r,sort_keys=True,ensure_ascii=False) for r in rows)
for key in ['employees','imports','attendance','vacations','permissions','impacts','drafts','closures']:
    assert canonical(source[key])==canonical(fresh[key]),'Source changed: '+key
assert not fresh['closures']
adjustments={'132':945.12,'217':249.48,'298':-315.04,'153':-24.20,'157':24.20}
confirmed_at=datetime.datetime.now(datetime.timezone.utc).isoformat()
plan=read('five_rh_adjustments_published.json')
assert len(plan)==78 and len({r['employee_id'] for r in plan})==78
old={r['employee_id']:r for r in fresh['drafts']}
for row in plan:
    assert row['period_label']==source['period'] and row['draft_status']=='publicado'
    employee_id=row['employee_id']
    if employee_id in adjustments:
        amount=adjustments[employee_id]
        assert row['manual_adjustment_amount']==amount
        assert not old.get(employee_id,{}).get('manual_adjustment_amount')
        snapshot=dict(row['source_snapshot'])
        snapshot['period35_excel_rh_adjustment']={
            'amount':amount,'confirmed_by_user':True,'confirmed_at':confirmed_at,
            'source_file':'NOMINA35.xlsx','period_only':True,
            'reason':'Ajuste RH del Excel confirmado por el usuario para el cierre del periodo 35.',
            'official_fiscal_unchanged':True,
        }
        row['source_snapshot']=snapshot
        note=f'Ajuste RH confirmado para el periodo 35: {amount:+.2f} MXN según NOMINA35.xlsx. Se aplica únicamente a esta semana; conserva el neto fiscal oficial de CONTPAQ y los salarios vigentes de Personal.'
        row['notes']='\n'.join(x for x in [row.get('notes','').strip(),note] if x)
    if old.get(employee_id,{}).get('draft_status')=='publicado':
        assert row==old[employee_id], 'Existing published row must remain unchanged'
manifest=read('closing_manifest.json')
manifest.update({'user_confirmed_five_adjustments':True,'confirmation_received_at':confirmed_at,
    'approved_adjustments':adjustments,'planned_totals':read('five_rh_adjustments_totals.json'),
    'preserved_cash_difference':{'manual_overtime_gabriel':163.0,'net_rounding':0.20},
    'next_action':'publish_then_verify_then_close_period35'})
def save(name,value):
    path=folder/name;path.write_text(json.dumps(value,ensure_ascii=False,indent=2));path.chmod(0o600)
save('confirmed_publication_plan.json',plan)
save('closing_manifest.json',manifest)
backup=Path('/Users/martinvelzat/DICSA/apps/dicsa_operacion/backups/hr_prenomina35_closure_2026-09-08')
backup.mkdir(exist_ok=True,mode=0o700);backup.chmod(0o700)
for name in ['app_source.json','prewrite_source.json','confirmed_publication_plan.json','closing_manifest.json','five_rh_adjustments_totals.json']:
    shutil.copy2(folder/name,backup/name);(backup/name).chmod(0o600)
print(json.dumps({'adjustments':5,'new_publications':77,'already_published_preserved':1,'prepared_total':manifest['planned_totals']['total']}))
