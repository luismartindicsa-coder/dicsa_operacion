"""Migrate user-confirmed opening balances. Default: transaction rollback."""
import os,sys,json,uuid,hashlib,argparse
from pathlib import Path
from decimal import Decimal as D
sys.path.insert(0,'/private/tmp/dicsa-hr-db-check')
import psycopg
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb
OUT=Path('.local/hr_current_loans_20260910')
MIGRATION=Path('supabase/migrations/20260910110000_support_hr_loan_opening_balances.sql')
PERIOD='Periodo 37 semanal · 04/09/2026 - 10/09/2026'
CUTOVER='2026-09-10'
SOURCE='Tabla de préstamos actuales proporcionada y aclarada por el usuario, 2026-09-10'
# employee, requested, principal, installment, total count, opening count, remaining
SPECS=[('223','2026-09-08',2500,500,5,0,2500),('104','2026-09-07',200,200,1,0,200),
 ('197','2026-09-03',2000,250,8,0,2000),('118','2026-08-17',2500,300,9,2,1900),
 ('118','2026-09-02',2000,200,10,1,1800),('114','2026-08-07',1500,300,5,4,300)]
SCOPE=['hr_employee_profiles','hr_prenomina_draft_rows','hr_payroll_period_closures',
 'hr_attendance_operational_periods','hr_loan_fund','hr_loan_payments','hr_loan_channel_changes']
def dump(path,value):
 path.write_text(json.dumps(value,default=str,ensure_ascii=False,indent=2))
def run(apply=False):
 OUT.mkdir(parents=True,exist_ok=True)
 checks=[]
 with psycopg.connect(Path('supabase/.temp/pooler-url').read_text().strip(),password=os.environ['SUPABASE_DB_PASSWORD'],
   sslmode='verify-full',sslrootcert='/private/tmp/dicsa-supabase-ca.crt',row_factory=dict_row) as conn:
  c=conn.cursor()
  c.execute("set local lock_timeout='10s'")
  c.execute('select capital from public.hr_loan_fund where id for update')
  assert c.fetchone()['capital']==15000
  def signatures():
   out={}
   for table in SCOPE:
    c.execute(f"select count(*) as n,md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text,'[]')) as hash from public.{table} t")
    out[table]=c.fetchone()
   return out
  before=signatures()
  c.execute('select to_jsonb(t) as row from public.hr_employee_loans t order by folio');prior=[r['row'] for r in c.fetchall()]
  c.execute('select id,nombre,empresa,employment_status,salario,salario_flujo,salario_real_percibido from public.hr_employee_profiles where id=any(%s) order by id', (sorted(set(s[0] for s in SPECS)),))
  people={r['id']:r for r in c.fetchall()};assert len(people)==5
  preflight=json.loads((OUT/'preflight.json').read_text())
  for old in preflight['candidates']:
   assert str(people[old['id']]['salario'])==old['salario']
   assert str(people[old['id']]['salario_flujo'])==old['salario_flujo']
   assert people[old['id']]['nombre']==old['nombre']
  c.execute('select end_date from public.hr_attendance_operational_periods where period_label=%s',(PERIOD,))
  assert str(c.fetchone()['end_date'])==CUTOVER
  c.execute("select id from auth.users where lower(email)='rh@dicsamx.com'");actor=str(c.fetchone()['id'])
  plan=[]
  for index,(employee,requested,principal,installment,count,paid_count,remaining) in enumerate(SPECS,1):
   person=people[employee];assert person['employment_status']!='baja'
   base=D(person['salario'] or 0)
   flow=D(person['salario_flujo']) if person['salario_flujo'] is not None else max(D(0),D(person['salario_real_percibido'] or base)-base)
   channel='fiscal' if flow==0 else 'flujo'
   assert channel==('flujo' if employee=='197' else 'fiscal')
   paid=principal-remaining;assert paid==installment*paid_count
   key=f'DICSA:current-loans:2026-09-10:{employee}:{requested}:{principal}'
   snapshot={'source':SOURCE,'source_row':index,'requested_on':requested,'as_of':CUTOVER,
     'first_pending_period':PERIOD,'original_principal':principal,'remaining_at_import':remaining,
     'reported_paid_installments':paid_count,'reported_paid_amount':paid,
     'historical_payment_dates':None,'historical_payment_channels':None,
     'channel_rule':'fiscal if total salary equals base; otherwise flujo',
     'salary_at_import':{'base':str(base),'flow':str(flow),'total':str(base+flow)},
     'entry_method':'Migración administrativa autorizada por el usuario; expediente de RH',
     'clarifications':(['Iliana: 0/1 corregido a 0/8 por el usuario'] if employee=='197' else
       ['Segundo préstamo de Miguel Ángel, confirmado por el usuario'] if employee=='118' and requested=='2026-09-02' else [])}
   row={'id':str(uuid.uuid5(uuid.NAMESPACE_URL,key+':loan')),'request_id':str(uuid.uuid5(uuid.NAMESPACE_URL,key)),
     'employee_id':employee,'employee_name':person['nombre'],'empresa':person['empresa'] or '',
     'principal':principal,'installment_count':count,'installment_amount':installment,
     'opening_paid_amount':paid,'opening_paid_installments':paid_count,'opening_snapshot':snapshot,
     'repayment_method':'nomina','frequency':'semanal','issued_on':CUTOVER,'first_due_on':CUTOVER,
     'payroll_channel':channel,'notes':'Saldo inicial migrado de la tabla de RH. Siguiente abono: periodo 37; después semanalmente.',
     'created_by':actor}
   plan.append(row)
  dump(OUT/'plan.json',plan)
  expected_ids={r['id'] for r in plan}
  assert not any(str(r['id']) not in expected_ids for r in prior), 'Unexpected existing loans: reconcile instead of duplicating'
  raw=MIGRATION.read_text();version,name=MIGRATION.stem.split('_',1)
  c.execute('select statements from supabase_migrations.schema_migrations where version=%s',(version,));existing=c.fetchone()
  schema_applied=not bool(existing)
  if existing:
   assert existing['statements']==[raw], 'Applied migration checksum mismatch'
  else:
   assert raw.startswith('begin;') and raw.rstrip().endswith('commit;')
   c.execute(raw[len('begin;'):raw.rfind('commit;')])
   c.execute('insert into supabase_migrations.schema_migrations(version,statements,name) values(%s,%s,%s)',(version,[raw],name))
  def insert_once():
   created=[]
   for row in plan:
    c.execute('select * from public.hr_employee_loans where request_id=%s',(row['request_id'],));old=c.fetchone()
    if old:
     for key,value in row.items():
      assert (old[key]==value if isinstance(value,(int,dict)) else str(old[key])==str(value)), f'Existing loan differs: {key}'
     continue
    cols=list(row)
    values=[Jsonb(row[k]) if isinstance(row[k],dict) else row[k] for k in cols]
    c.execute(f"insert into public.hr_employee_loans({','.join(cols)}) values({','.join(['%s']*len(cols))}) returning id",values)
    created.append(str(c.fetchone()['id']))
   return created
  inserted=insert_once();assert insert_once()==[]
  checks.append('import_idempotent')
  c.execute('select count(*) as n,sum(principal) as principal,sum(opening_paid_amount) as paid,sum(principal-opening_paid_amount) as outstanding from public.hr_employee_loans')
  totals=c.fetchone();assert totals=={'n':6,'principal':D(10700),'paid':D(2000),'outstanding':D(8700)},totals
  c.execute('select public.hr_loan_available() as available');assert c.fetchone()['available']==6300
  dues=[]
  for row in plan:
   c.execute("select public.hr_loan_due(%s,'2026-08-27') as p35,public.hr_loan_due(%s,'2026-09-03') as p36,public.hr_loan_due(%s,'2026-09-10') as p37,public.hr_loan_due(%s,'2027-01-01') as all_due",(row['id'],)*4)
   d=c.fetchone();assert d['p35']==0 and d['p36']==0 and d['p37']==row['installment_amount'] and d['all_due']==row['principal']-row['opening_paid_amount'],d
   dues.append({'employee':row['employee_name'],'request_date':row['opening_snapshot']['requested_on'],'channel':row['payroll_channel'],'next':d['p37']})
  checks+=['fund_6300_available_8700_outstanding','period_35_and_36_unaffected_by_loan_dues','period_37_first_pending_only']
  c.execute('select count(*) as n from public.hr_loan_payments');assert c.fetchone()['n']==0
  # Functional DB checks run only in rollback mode; never persist test receipts or payroll closures.
  if not apply:
   c.execute('savepoint functional')
   c.execute("select set_config('request.jwt.claims',%s,true)",(json.dumps({'sub':actor,'email':'rh@dicsamx.com','role':'authenticated'}),))
   c.execute('set local role authenticated')
   def reject(query,args,expected):
    try:
     with conn.transaction():c.execute(query,args)
    except psycopg.Error as e:
     assert expected in str(e), str(e);return
    raise AssertionError('Expected rejection: '+expected)
   cash='select public.hr_loan_record_cash_payment(%s,%s,%s,%s,%s)'
   mig=plan[3]
   reject(cash,(str(uuid.uuid4()),mig['id'],1901,CUTOVER,'rollback'),'saldo pendiente')
   args=(str(uuid.uuid4()),mig['id'],1800,CUTOVER,'rollback')
   c.execute(cash,args);c.execute(cash,args)
   c.execute('reset role')
   c.execute("select public.hr_loan_due(%s,'2026-10-15') as before_last,public.hr_loan_due(%s,'2026-10-22') as last,public.hr_loan_available() as available",(mig['id'],mig['id']))
   assert c.fetchone()=={'before_last':D(0),'last':D(100),'available':D(8100)}
   c.execute('set local role authenticated')
   reject(cash,(str(uuid.uuid4()),mig['id'],101,CUTOVER,'rollback'),'saldo pendiente')
   c.execute(cash,(str(uuid.uuid4()),mig['id'],100,CUTOVER,'rollback'))
   reject('select public.hr_loan_set_payroll_channel(%s,%s,%s,%s,%s)',(str(uuid.uuid4()),mig['id'],'fiscal','flujo','rollback'),'liquidado')
   c.execute('rollback to savepoint functional')
   checks+=['opening_payments_not_recollected','cash_payment_idempotent_and_no_overpay','last_miguel_payment_exactly_100','paid_loan_cannot_change_channel']
   # New fixed-amount creation via the public RPC, including legacy defaults.
   c.execute('savepoint rpc')
   c.execute("select set_config('request.jwt.claims',%s,true)",(json.dumps({'sub':actor,'email':'rh@dicsamx.com','role':'authenticated'}),));c.execute('set local role authenticated')
   create='select public.hr_loan_create(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) as id'
   args=(str(uuid.uuid4()),'118',2500,9,'nomina','semanal',CUTOVER,CUTOVER,'rollback','fiscal',300)
   c.execute(create,args);loanid=c.fetchone()['id'];c.execute(create,args);assert c.fetchone()['id']==loanid
   reject(create,(str(uuid.uuid4()),'118',2500,8,'nomina','semanal',CUTOVER,CUTOVER,'rollback','fiscal',300),'número de pagos')
   reject(create,(str(uuid.uuid4()),'118',2500,9,'nomina','semanal',CUTOVER,CUTOVER,'rollback','fiscal',0),'cuota')
   c.execute('rollback to savepoint rpc');checks.append('new_fixed_amount_rpc_validates_schedule_and_retries')
   # Publish test snapshots for the five borrowers under a disposable period label.
   c.execute('savepoint payroll')
   c.execute("select set_config('request.jwt.claims',%s,true)",(json.dumps({'sub':actor,'email':'rh@dicsamx.com','role':'authenticated'}),));c.execute('set local role authenticated')
   label='Prueba apertura '+uuid.uuid4().hex[:8]+' · 04/09/2026 - 10/09/2026'
   for employee in sorted(people):
    rows=[r for r in plan if r['employee_id']==employee]
    allocations=[{'loan_id':r['id'],'amount':r['installment_amount'],'channel':r['payroll_channel']} for r in rows]
    flow=sum(a['amount'] for a in allocations if a['channel']=='flujo');fiscal=sum(a['amount'] for a in allocations if a['channel']=='fiscal')
    snap={'incidences_informational':True,'contpaq_official_net':1700,'loan_fund':{'version':2,'end_date':CUTOVER,
      'requested_amount':flow+fiscal,'amount':flow,'fiscal_amount':fiscal,'pending_amount':0,'fiscal_ready':True,'dues':allocations,'allocations':allocations}}
    c.execute('''insert into public.hr_prenomina_draft_rows(period_label,employee_id,employee_name,empresa,draft_status,
      fiscal_net_amount,cash_salary_amount,loan_deduction_amount,source_snapshot)
      values(%s,%s,'Prueba revertida','PRUEBA','publicado',1700,%s,%s,%s)''',(label,employee,594.72 if flow else 0,flow,Jsonb(snap)))
   c.execute("insert into public.hr_payroll_period_closures(period_label,status,closed_at,closed_by) values(%s,'cerrado',now(),%s) returning id",(label,actor));closure=c.fetchone()['id']
   c.execute('select payroll_channel,sum(amount) as total from public.hr_loan_payments group by payroll_channel');assert {r['payroll_channel']:r['total'] for r in c.fetchall()}=={'fiscal':1500,'flujo':250}
   c.execute("update public.hr_payroll_period_closures set status='cerrado' where id=%s",(closure,));c.execute('select count(*) as n from public.hr_loan_payments');assert c.fetchone()['n']==6
   c.execute('select min(fiscal_net_amount) as low,max(fiscal_net_amount) as high,sum(loan_deduction_amount) as loan from public.hr_prenomina_draft_rows where period_label=%s',(label,));assert c.fetchone()=={'low':1700,'high':1700,'loan':250}
   c.execute('reset role');c.execute('select public.hr_loan_available() as available');assert c.fetchone()['available']==8050
   c.execute('rollback to savepoint payroll');checks.append('payroll_close_recovers_1750_once_without_modifying_fiscal_net')
  after=signatures();assert before==after,'Unrelated data changed; rolling back'
  c.execute('select to_jsonb(t) as row from public.hr_employee_loans t order by folio');saved=[r['row'] for r in c.fetchall()]
  result={'mode':'applied' if apply else 'dry_run_rolled_back','schema_applied':schema_applied,'migration':MIGRATION.name,
    'migration_sha256':hashlib.sha256(raw.encode()).hexdigest(),'inserted':len(inserted),'totals':totals,
    'available':6300,'next_period':PERIOD,'next_fiscal':1500,'next_flow':250,'next_installments':dues,
    'existing_personnel_payroll_closures_fund_capital_payments_unchanged':True,'checks':checks}
  if apply:
   tested=json.loads((OUT/'dry_run.json').read_text())
   assert tested['migration_sha256']==result['migration_sha256']
   assert 'payroll_close_recovers_1750_once_without_modifying_fiscal_net' in tested['checks']
   dump(OUT/'before_apply.json',{'loans':prior,'signatures':before})
   conn.commit()
   dump(OUT/'saved_rows.json',saved)
  else:conn.rollback()
  dump(OUT/('applied.json' if apply else 'dry_run.json'),result)
  print(json.dumps(result,default=str,ensure_ascii=False))
if __name__=='__main__':
 try:run('--apply' in sys.argv)
 except Exception as e:
  print(type(e).__name__+': '+str(e).replace(os.environ.get('SUPABASE_DB_PASSWORD','__missing__'),'[redacted]'));sys.exit(1)
