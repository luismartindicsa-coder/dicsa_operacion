begin;
-- Admit the corrected model without rewriting historical snapshots or source data.
create or replace function public.direction_save_profitability_snapshot(p_start date,p_end date,p_expected_revision integer,p_payload jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare saved_config jsonb; old_revision integer; result uuid; master_config jsonb; master_revision integer; r jsonb;
begin
  if not coalesce(public.direction_program_can_manage(),false) then raise exception 'Sin permiso' using errcode='42501'; end if;
  if p_start is null or p_end is null or p_end not between p_start and p_start+365 or p_expected_revision is null or p_expected_revision<0 then raise exception 'Periodo o versión inválida'; end if;
  perform pg_advisory_xact_lock(hashtextextended('direction-profitability-master',0));
  perform pg_advisory_xact_lock(hashtextextended('direction-profitability:'||p_start::text||':'||p_end::text,0));
  select revision,config into old_revision,saved_config from public.direction_profitability_reviews where period_start=p_start and period_end=p_end;
  if coalesce(old_revision,0)<>p_expected_revision then raise exception 'El corte cambió en otra sesión' using errcode='PT409'; end if;
  if saved_config is null then saved_config:='{"identities":{},"recipes":{},"costs":{},"companies":{},"excluded_purchases":{}}'; end if;
  if p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>20000000
    or p_payload->'config' is distinct from saved_config
    or p_payload->>'start' is distinct from p_start::text or p_payload->>'end' is distinct from p_end::text
    or p_payload->'review_revision' is distinct from to_jsonb(p_expected_revision)
    or coalesce(p_payload->>'engine_version','') not in ('1','2','3')
    or coalesce(p_payload->>'evidence_signature','') !~ '^[0-9a-f]{64}$'
    or jsonb_typeof(p_payload->'companies') is distinct from 'array' then raise exception 'Corte inconsistente con las reglas guardadas'; end if;
  if p_payload->>'engine_version' in ('2','3') then
    select revision,config into master_revision,master_config from public.direction_profitability_master where id=1;
    if p_payload->'master_revision' is distinct from to_jsonb(coalesce(master_revision,0)) or p_payload->'master_config' is distinct from coalesce(master_config,'{"rules":[]}'::jsonb) then raise exception 'Los parámetros cambiaron; consulta de nuevo antes de guardar' using errcode='PT409'; end if;
    for r in select value from jsonb_array_elements(coalesce(p_payload->'shared_cost_review_evidence','[]'::jsonb)) loop
      if not exists(select 1 from public.direction_profitability_reviews v where v.period_start=(r->>'period_start')::date and v.period_end=(r->>'period_end')::date and v.revision=(r->>'revision')::integer and v.config->'costs'=r->'costs') then raise exception 'La conciliación compartida cambió' using errcode='PT409'; end if;
    end loop;
  end if;
  if p_payload->>'engine_version'='3' and coalesce(p_payload->>'inference_model','') not in ('operational-account-v1','operational-account-v2','documentary') then raise exception 'Modelo de inferencia inválido'; end if;
  insert into public.direction_profitability_snapshots(period_start,period_end,review_revision,payload,created_by) values(p_start,p_end,p_expected_revision,p_payload,auth.uid()) returning id into result;
  return result;
end $$;
commit;
