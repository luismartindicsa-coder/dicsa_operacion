import os,sys,json,uuid,hashlib
from pathlib import Path
from decimal import Decimal as D
sys.path.insert(0,'/private/tmp/dicsa-hr-db-check')
import psycopg
from psycopg.rows import dict_row
FILE=Path('supabase/migrations/20260910120000_add_prenomina_manual_fiscal_deduction.sql')
OUT=Path('.local/hr_manual_fiscal_20260910');OUT.mkdir(exist_ok=True,parents=True)
def run(apply):
 with psycopg.connect(Path('supabase/.temp/pooler-url').read_text().strip(),password=os.environ['SUPABASE_DB_PASSWORD'],sslmode='verify-full',sslrootcert='/private/tmp/dicsa-supabase-ca.crt',row_factory=dict_row) as conn:
  c=conn.cursor();checks=[]
  c.execute("set local lock_timeout='10s'")
  def signatures():
   values={}
   for table in ['hr_prenomina_draft_rows','hr_payroll_period_closures','hr_payroll_receipt_documents','hr_employee_profiles','hr_loan_fund','hr_employee_loans','hr_loan_payments']:
    expr="to_jsonb(t) - array['fiscal_manual_deduction_amount','fiscal_manual_deduction_reason']" if table=='hr_prenomina_draft_rows' else 'to_jsonb(t)'
    c.execute(f"select count(*) as n, md5(coalesce(jsonb_agg({expr} order by id)::text,'[]')) as hash from public.{table} t")
    values[table]=c.fetchone()
   return values
  before=signatures();raw=FILE.read_text();version,name=FILE.stem.split('_',1)
  c.execute('select statements from supabase_migrations.schema_migrations where version=%s',(version,));old=c.fetchone()
  if old:assert old['statements']==[raw]
  else:
   c.execute(raw[len('begin;'):raw.rfind('commit;')])
   c.execute('insert into supabase_migrations.schema_migrations(version,statements,name) values(%s,%s,%s)',(version,[raw],name))
  c.execute('select count(*) as n from public.hr_prenomina_fiscal_deduction_changes');assert c.fetchone()['n']==0
  c.execute('select count(*) as n from public.hr_prenomina_draft_rows where fiscal_manual_deduction_amount<>0');assert c.fetchone()['n']==0
  if not apply:
   c.execute('savepoint functional')
   c.execute("select id from auth.users where lower(email)='rh@dicsamx.com'");actor=str(c.fetchone()['id'])
   c.execute("select id from public.hr_employee_profiles where employment_status <> 'baja' order by id limit 1");employee=c.fetchone()['id']
   claims=json.dumps({'sub':actor,'email':'rh@dicsamx.com','role':'authenticated'})
   c.execute("select set_config('request.jwt.claims',%s,true)",(claims,));c.execute('set local role authenticated')
   label='Prueba fiscal manual '+uuid.uuid4().hex[:8]+' · 21/08/2026 - 27/08/2026'
   c.execute('''insert into public.hr_prenomina_draft_rows(period_label,employee_id,employee_name,empresa,draft_status,fiscal_net_amount,cash_salary_amount,
    fiscal_manual_deduction_amount,fiscal_manual_deduction_reason,fiscal_late_deduction_amount,source_snapshot)
    values(%s,%s,'Prueba revertida','PRUEBA','borrador',1700,300,150,'Ajuste de prueba',100,
      '{"contpaq_official_net":1700,"incidences_informational":true}') returning id''',(label,employee));draft=str(c.fetchone()['id'])
   def assert_audit(count):
    c.execute('select count(*) as n from public.hr_prenomina_fiscal_deduction_changes where draft_id=%s',(draft,));assert c.fetchone()['n']==count
   assert_audit(1)
   c.execute('select fiscal_net_amount,cash_salary_amount,source_snapshot from public.hr_prenomina_draft_rows where id=%s',(draft,));row=c.fetchone();assert row['fiscal_net_amount']==1700 and row['cash_salary_amount']==300 and row['source_snapshot']['contpaq_official_net']==1700
   checks.append('manual_discount_preserves_official_net_and_flow')
   c.execute('update public.hr_prenomina_draft_rows set fiscal_manual_deduction_amount=150 where id=%s',(draft,));assert_audit(1)
   c.execute('update public.hr_prenomina_draft_rows set fiscal_manual_deduction_amount=200 where id=%s',(draft,));assert_audit(2)
   c.execute('select previous_amount,amount,changed_by from public.hr_prenomina_fiscal_deduction_changes where draft_id=%s and amount=200',(draft,));r=c.fetchone();assert r['previous_amount']==150 and r['amount']==200 and str(r['changed_by'])==actor
   checks.append('audit_records_actor_before_after_and_skips_unchanged_saves')
   def reject(q,args,expected):
    try:
     with conn.transaction():c.execute(q,args)
    except psycopg.Error as e:
     assert expected in str(e),str(e);return
    raise AssertionError('Expected rejection: '+expected)
   update='update public.hr_prenomina_draft_rows set fiscal_manual_deduction_amount=%s where id=%s'
   reject(update,(-1,draft),'check constraint');reject(update,('NaN',draft),'supera el fiscal')
   reject(update,(1701,draft),'supera el fiscal')
   reject('update public.hr_prenomina_draft_rows set fiscal_manual_deduction_reason=%s where id=%s',('   ',draft),'check constraint')
   c.execute(update,(1700,draft))
   checks.append('validates_nonnegative_finite_amount_reason_and_available_fiscal')
   c.execute("update public.hr_prenomina_draft_rows set fiscal_manual_deduction_amount=0,fiscal_manual_deduction_reason='' where id=%s",(draft,));assert_audit(4)
   checks.append('clearing_deduction_is_audited')
   c.execute("select set_config('request.jwt.claims',%s,true)",(json.dumps({'sub':str(uuid.uuid4()),'role':'authenticated'}),))
   reject("update public.hr_prenomina_draft_rows set fiscal_manual_deduction_amount=100,fiscal_manual_deduction_reason='Intento' where id=%s",(draft,),'no tiene acceso')
   c.execute('select count(*) as n from public.hr_prenomina_fiscal_deduction_changes');assert c.fetchone()['n']==0
   checks.append('only_authorized_rh_can_change_or_read_audit')
   c.execute("select set_config('request.jwt.claims',%s,true)",(claims,))
   c.execute("update public.hr_prenomina_draft_rows set draft_status='publicado',fiscal_manual_deduction_amount=150,fiscal_manual_deduction_reason='Ajuste probado' where id=%s",(draft,))
   c.execute("insert into public.hr_payroll_period_closures(period_label,status,closed_at,closed_by) values(%s,'cerrado',now(),%s)",(label,actor))
   reject(update,(100,draft),'cerrado');checks.append('closed_payroll_cannot_be_rewritten')
   c.execute('rollback to savepoint functional')
  after=signatures();assert before==after,'Existing rows changed; rollback'
  result={'mode':'applied' if apply else 'dry_run_rolled_back','migration':FILE.name,'sha256':hashlib.sha256(raw.encode()).hexdigest(),'checks':checks,
    'existing_payroll_loans_people_receipts_unchanged':True,'manual_discounts_applied_to_employees':0,'before':before,'after':after}
  if apply:
   tested=json.loads((OUT/'dry_run.json').read_text());assert tested['sha256']==result['sha256'] and len(tested['checks'])==6
   conn.commit()
  else:conn.rollback()
  (OUT/('applied.json' if apply else 'dry_run.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2))
  OUT.chmod(0o700)
  for p in OUT.iterdir():p.chmod(0o600)
  print(json.dumps({k:v for k,v in result.items() if k not in ('before','after')},ensure_ascii=False))
try:run('--apply' in sys.argv)
except Exception as e:
 print(type(e).__name__+': '+str(e).replace(os.environ.get('SUPABASE_DB_PASSWORD','__missing__'),'[redacted]'));sys.exit(1)
