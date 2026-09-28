begin;

alter table public.direction_execution_actuals
  add column agenda_snapshot jsonb not null default '[]',
  add column agenda_synced_revision integer not null default 0;

-- Compare only the fields changed by reconciliation, plus the group identity.
create function public.direction_execution_agenda_identity(p_row jsonb) returns jsonb
language sql immutable set search_path=public as $$
  select jsonb_build_array(p_row->>'id',p_row->>'ship_date',
    public.direction_execution_client(p_row->>'client_name'),
    p_row->>'planning_material_code',p_row->'planned_units',p_row->>'status');
$$;

create function public.direction_sync_execution_agenda(p_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare
  a public.direction_execution_actuals;
  s public.direction_shipment_plans;
  v_entry jsonb; v_previous jsonb; v_before jsonb; v_after jsonb;
  v_snapshot jsonb := '[]'; v_candidates uuid[] := '{}'; v_used uuid[] := '{}';
  v_id uuid; v_load integer; v_bulk boolean;
begin
  select * into strict a from public.direction_execution_actuals where id=p_id for update;
  if a.kind<>'shipment' then return; end if;
  v_bulk := a.material_code in ('CHATARRA','METAL','PAPEL','PLASTICO','MADERA');
  if not a.active then
    -- Undo only our own last application. Never overwrite a later manual edit.
    for v_entry in select value from jsonb_array_elements(a.agenda_snapshot) loop
      select * into s from public.direction_shipment_plans where id=(v_entry->>'id')::uuid for update;
      if not found or public.direction_execution_agenda_identity(to_jsonb(s)) is distinct from
          public.direction_execution_agenda_identity(v_entry->'after') then
        raise exception 'La agenda cambió después de confirmar. Vuelve a confirmar el resultado real antes de restablecer.' using errcode='PT409';
      end if;
      v_before := v_entry->'before';
      if v_before is not null and v_before<>'null'::jsonb then
        update public.direction_shipment_plans set planned_units=(v_before->>'planned_units')::integer,
          status=v_before->>'status' where id=s.id returning to_jsonb(direction_shipment_plans.*) into v_after;
      else
        -- Added actual loads remain visible as cancelled when a confirmation is undone.
        update public.direction_shipment_plans set status='cancelado' where id=s.id
          returning to_jsonb(direction_shipment_plans.*) into v_after;
      end if;
      v_snapshot := v_snapshot || jsonb_build_array(jsonb_build_object('id',s.id,'before',v_before,'after',v_after));
    end loop;
  else
    -- Stable row identities preserve income settings and allow corrections without duplicates.
    -- Previously cancelled manual rows are left alone; rows cancelled by Real are reusable.
    for s in select * from public.direction_shipment_plans
      where ship_date=a.op_date and planning_material_code=a.material_code
        and public.direction_execution_client(client_name)=a.client_name
        and (status<>'cancelado' or id in (select (value->>'id')::uuid from jsonb_array_elements(a.agenda_snapshot)))
      order by created_at,id for update loop
      v_candidates := array_append(v_candidates,s.id);
    end loop;
    for v_load in select value::text::integer from jsonb_array_elements(a.load_quantities) loop
      select * into s from public.direction_shipment_plans
        where id=any(v_candidates) and not(id=any(v_used))
        order by (planned_units=v_load) desc,array_position(v_candidates,id) limit 1;
      if found then
        v_before := to_jsonb(s);
        select value into v_previous from jsonb_array_elements(a.agenda_snapshot) where value->>'id'=s.id::text;
        if found and public.direction_execution_agenda_identity(to_jsonb(s))=
            public.direction_execution_agenda_identity(v_previous->'after') then
          v_before := v_previous->'before';
        end if;
        -- Do not rewrite metadata, pricing links, client spelling or dates.
        if s.planned_units<>v_load or s.status<>'embarcado' then
          update public.direction_shipment_plans set planned_units=v_load,status='embarcado'
            where id=s.id returning * into s;
        end if;
      else
        v_before := null;
        insert into public.direction_shipment_plans(ship_date,client_name,commercial_material_code,
          planning_material_code,material_scope,quantity_unit,planned_units,status,notes,created_by)
        values(a.op_date,a.client_name,a.material_code,a.material_code,
          case when v_bulk then 'general' else 'commercial' end,
          case when v_bulk then 'KG' else 'PACAS' end,v_load,'embarcado',nullif(a.notes,''),a.updated_by)
        returning * into s;
      end if;
      v_used := array_append(v_used,s.id);
      v_snapshot := v_snapshot || jsonb_build_array(jsonb_build_object('id',s.id,'before',v_before,'after',to_jsonb(s)));
    end loop;
    foreach v_id in array v_candidates loop
      if v_id=any(v_used) then continue; end if;
      select * into s from public.direction_shipment_plans where id=v_id;
      v_before := to_jsonb(s);
      select value into v_previous from jsonb_array_elements(a.agenda_snapshot) where value->>'id'=s.id::text;
      if found and public.direction_execution_agenda_identity(to_jsonb(s))=
          public.direction_execution_agenda_identity(v_previous->'after') then
        v_before := v_previous->'before';
      end if;
      if s.status<>'cancelado' then
        update public.direction_shipment_plans set status='cancelado' where id=s.id returning * into s;
      end if;
      v_snapshot := v_snapshot || jsonb_build_array(jsonb_build_object('id',s.id,'before',v_before,'after',to_jsonb(s)));
    end loop;
  end if;
  update public.direction_execution_actuals set agenda_snapshot=v_snapshot,agenda_synced_revision=revision
    where id=a.id returning * into a;
  -- The execution and all agenda changes belong to the same atomic revision.
  update public.direction_execution_actual_revisions set payload=to_jsonb(a)
    where actual_id=a.id and revision=a.revision;
end;
$$;
revoke all on function public.direction_sync_execution_agenda(uuid) from public,anon,authenticated;

alter function public.direction_save_execution_actual(text,date,text,text,text,integer,jsonb,integer,text,integer,uuid,boolean)
  rename to direction_save_execution_actual_record;
revoke all on function public.direction_save_execution_actual_record(text,date,text,text,text,integer,jsonb,integer,text,integer,uuid,boolean)
  from public,anon,authenticated;
create function public.direction_save_execution_actual(
  p_kind text,p_date date,p_material text,p_client text,p_shift text,
  p_quantity integer,p_loads jsonb,p_observed integer,p_notes text,
  p_expected_revision integer,p_program_id uuid default null,p_clear boolean default false
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_result jsonb;
begin
  v_result := public.direction_save_execution_actual_record(p_kind,p_date,p_material,p_client,p_shift,
    p_quantity,p_loads,p_observed,p_notes,p_expected_revision,p_program_id,p_clear);
  if p_kind='shipment' then
    perform public.direction_sync_execution_agenda((v_result->>'id')::uuid);
    select to_jsonb(a) into v_result from public.direction_execution_actuals a where id=(v_result->>'id')::uuid;
  end if;
  return v_result;
end;
$$;
revoke all on function public.direction_save_execution_actual(text,date,text,text,text,integer,jsonb,integer,text,integer,uuid,boolean) from public,anon;
grant execute on function public.direction_save_execution_actual(text,date,text,text,text,integer,jsonb,integer,text,integer,uuid,boolean) to authenticated;

-- Apply existing confirmations only when the agenda still matches their saved
-- baseline. Later edits are left for the user to review and confirm again.
do $$
declare a public.direction_execution_actuals; v_current jsonb; v_original jsonb;
begin
  for a in select * from public.direction_execution_actuals where kind='shipment' and active order by op_date,id for update loop
    select coalesce(jsonb_agg(public.direction_execution_agenda_identity(to_jsonb(s)) order by s.id),'[]') into v_current
      from public.direction_shipment_plans s where ship_date=a.op_date and planning_material_code=a.material_code
        and status<>'cancelado' and public.direction_execution_client(client_name)=a.client_name;
    select coalesce(jsonb_agg(public.direction_execution_agenda_identity(value) order by value->>'id'),'[]') into v_original
      from jsonb_array_elements(a.planned_snapshot);
    if v_current=v_original then
      update public.direction_execution_actuals set revision=revision+1,updated_at=now() where id=a.id returning * into a;
      insert into public.direction_execution_actual_revisions(actual_id,revision,payload) values(a.id,a.revision,to_jsonb(a));
      perform public.direction_sync_execution_agenda(a.id);
      update public.direction_execution_actual_revisions set payload=payload||'{"agenda_backfill":true}'::jsonb
        where actual_id=a.id and revision=a.revision;
    end if;
  end loop;
end;
$$;
comment on column public.direction_execution_actuals.agenda_snapshot is 'Agenda antes/después de cada aplicación; permite corregir, auditar y restaurar sin duplicar el origen operativo.';
commit;
