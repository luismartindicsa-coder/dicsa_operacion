-- Additive preparation only: does not modify or recalculate existing app rows.
-- Invoker rights preserve the caller's existing RLS/table permissions.
begin;
create table public.app_preserving_save_receipts (
  actor_id uuid not null default auth.uid(),
  request_id uuid not null,
  request_body jsonb not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key (actor_id, request_id)
);
alter table public.app_preserving_save_receipts enable row level security;
grant select, insert on public.app_preserving_save_receipts to authenticated;
create policy own_preserving_save_receipts on public.app_preserving_save_receipts
  for all to authenticated using (actor_id = auth.uid()) with check (actor_id = auth.uid());

-- Read-only integrity check. It can see references hidden by child-table RLS,
-- but cannot change them. A rename aborts rather than cascading those rows.
create function public.app_hr_profile_has_references(p_id text)
returns boolean language plpgsql security definer
set search_path = pg_catalog, public as $$
declare dependency record; remaining boolean;
begin
  if auth.uid() is null then raise exception 'Se requiere una sesión.' using errcode='42501'; end if;
  for dependency in
    select c.conrelid::regclass as relation, a.attname as column_name,
           cardinality(c.conkey) as key_count, parent.attname as parent_column
    from pg_constraint c
    join pg_attribute a on a.attrelid=c.conrelid and a.attnum=c.conkey[1]
    join pg_attribute parent on parent.attrelid=c.confrelid and parent.attnum=c.confkey[1]
    where c.contype='f' and c.confrelid='public.hr_employee_profiles'::regclass
  loop
    if dependency.key_count<>1 or dependency.parent_column<>'id' then
      raise exception 'El cambio de ID requiere revisar una relación compuesta.' using errcode='22023';
    end if;
    execute format('select exists(select 1 from %s where %I::text=$1)',dependency.relation,dependency.column_name)
      into remaining using p_id;
    if remaining then return true; end if;
  end loop;
  return false;
end;
$$;
revoke all on function public.app_hr_profile_has_references(text) from public, anon;
grant execute on function public.app_hr_profile_has_references(text) to authenticated;

create function public.app_commit_preserving_data(
  p_request_id uuid, p_operations jsonb, p_checks jsonb default '[]'::jsonb
) returns jsonb language plpgsql security invoker
set search_path = pg_catalog, public
set lock_timeout = '5s'
as $$
declare
  allowed constant text[] := array[
    'maintenance_orders','maintenance_tasks','maintenance_materials','maintenance_time_logs',
    'hr_employee_profiles','hr_employee_documents',
    'compras_tickets','compras_provider_movements','compras_ticket_payment_applications'];
  op jsonb; chk jsonb; tbl text; col text; verb text; rid text;
  current_row jsonb; expected_row jsonb; normalized jsonb; patch jsonb;
  columns_sql text; values_sql text; result jsonb := '[]'::jsonb;
  body jsonb := jsonb_build_object('operations',p_operations,'checks',p_checks);
  prior public.app_preserving_save_receipts;
  actual_rows jsonb; expected_rows jsonb; dependency record;
begin
  if auth.uid() is null then raise exception 'Se requiere una sesión.' using errcode='42501'; end if;
  if p_request_id is null or jsonb_typeof(p_operations) <> 'array'
      or jsonb_typeof(p_checks) <> 'array' or p_operations is null or p_checks is null then
    raise exception 'Solicitud de guardado inválida.' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || p_request_id::text,0));
  select * into prior from public.app_preserving_save_receipts
    where actor_id=auth.uid() and request_id=p_request_id;
  if found then
    if prior.request_body <> body then raise exception 'La solicitud cambió durante el reintento.' using errcode='22023'; end if;
    return prior.result;
  end if;

  -- Reconciliation snapshots need phantom protection, including legacy clients.
  -- Locks are short-lived, ordered, and only needed for the checked tables.
  for tbl in select distinct value->>'table' from jsonb_array_elements(p_checks) order by 1 loop
    if not tbl = any(allowed) then raise exception 'Tabla no permitida.' using errcode='22023'; end if;
    execute format('lock table public.%I in share row exclusive mode',tbl);
  end loop;
  for chk in select value from jsonb_array_elements(p_checks) loop
    tbl := chk->>'table'; col := chk->>'column';
    if not ((tbl in ('compras_tickets','compras_provider_movements') and col='provider_id')
        or (tbl='compras_ticket_payment_applications' and col='ticket_id')
        or (tbl in ('maintenance_tasks','maintenance_materials','maintenance_time_logs') and col='ot_id'))
        or jsonb_typeof(chk->'ids') <> 'array' or jsonb_typeof(chk->'rows') <> 'array' then
      raise exception 'Comprobación inválida.' using errcode='22023';
    end if;
    execute format('select coalesce(jsonb_agg(to_jsonb(t) order by id),''[]''::jsonb)
      from public.%I t where %I::text in (select jsonb_array_elements_text($1))',tbl,col)
      into actual_rows using chk->'ids';
    execute format('select coalesce(jsonb_agg(to_jsonb(t) order by id),''[]''::jsonb)
      from jsonb_populate_recordset(null::public.%I,$1) t',tbl)
      into expected_rows using chk->'rows';
    if actual_rows <> expected_rows then
      raise exception 'Los datos cambiaron en otro equipo. No se aplicó ningún cambio; vuelve a cargar antes de guardar.' using errcode='40001';
    end if;
  end loop;

  for op in select value from jsonb_array_elements(p_operations) loop
    tbl := op->>'table'; verb := op->>'action'; rid := op->>'id';
    if tbl is null or not tbl = any(allowed) or rid is null or rid='' or
       verb is null or verb not in ('insert','update','delete','rename') then
      raise exception 'Operación inválida.' using errcode='22023';
    end if;
    if verb='delete' and tbl in ('hr_employee_profiles','maintenance_orders','compras_tickets') then
      raise exception 'Esta operación no elimina expedientes ni cabeceras.' using errcode='22023';
    end if;
    execute format('select to_jsonb(t) from public.%I t where id::text=$1 for update',tbl)
      into current_row using rid;
    patch := coalesce(op->'values','{}'::jsonb);
    if jsonb_typeof(patch) <> 'object' then raise exception 'Campos inválidos.' using errcode='22023'; end if;
    for col in select jsonb_object_keys(patch) loop
      if not exists(select 1 from pg_attribute where attrelid=format('public.%I',tbl)::regclass
          and attname=col and attnum>0 and not attisdropped and attgenerated='')
          or col in ('created_at','updated_at') or (col='id' and verb='update') then
        raise exception 'Campo no permitido: %.',col using errcode='22023';
      end if;
    end loop;
    if verb='insert' then
      if current_row is not null or patch->>'id' is distinct from rid then
        raise exception 'El registro ya existe o su identidad cambió.' using errcode='40001';
      end if;
    else
      if current_row is null or jsonb_typeof(op->'expected') is distinct from 'object'
          or op->'expected'='{}'::jsonb then
        raise exception 'No se encontró la versión original del registro.' using errcode='40001';
      end if;
      expected_row := op->'expected';
      for col in select jsonb_object_keys(expected_row) loop
        if not current_row ? col then raise exception 'Campo original desconocido: %.',col using errcode='22023'; end if;
      end loop;
      execute format('select to_jsonb(t) from jsonb_populate_record(null::public.%I,$1) t',tbl)
        into normalized using expected_row;
      for col in select jsonb_object_keys(expected_row) loop
        if current_row->col is distinct from normalized->col then
          raise exception 'El registro cambió en otro equipo. No se aplicó ningún cambio.' using errcode='40001';
        end if;
      end loop;
    end if;
    if verb='delete' then
      execute format('delete from public.%I where id::text=$1 returning to_jsonb(%I)',tbl,tbl)
        into normalized using rid;
    elsif verb='rename' then
      -- Preserve every referencing row; immutable/closed histories abort the
      -- entire operation instead of cascading a deletion or leaving two IDs.
      if tbl<>'hr_employee_profiles' or coalesce(patch->>'id','') in ('',rid) then
        raise exception 'Cambio de ID inválido.' using errcode='22023';
      end if;
      execute 'insert into public.hr_employee_profiles select (jsonb_populate_record(null::public.hr_employee_profiles,$1)).*'
        using current_row || patch;
      for dependency in
        select c.conrelid::regclass as relation, a.attname as column_name
        from pg_constraint c join pg_attribute a on a.attrelid=c.conrelid and a.attnum=c.conkey[1]
        where c.contype='f' and c.confrelid='public.hr_employee_profiles'::regclass
          and cardinality(c.conkey)=1 order by c.conrelid, a.attname
      loop
        -- Some history tables intentionally allow SELECT only. An empty such
        -- table must not reject every rename. Never widen access: skip it and
        -- let the all-references check below abort if a relation remains.
        if has_column_privilege(dependency.relation,dependency.column_name,'UPDATE')
          and has_column_privilege(dependency.relation,dependency.column_name,'SELECT') then
          execute format('update %s set %I=$1 where %I=$2',dependency.relation,dependency.column_name,dependency.column_name)
            using patch->>'id',rid;
        end if;
      end loop;
      if public.app_hr_profile_has_references(rid) then
        raise exception 'No se pudieron trasladar todas las relaciones del expediente. No se aplicó ningún cambio.' using errcode='40001';
      end if;
      delete from public.hr_employee_profiles where id=rid;
      select to_jsonb(t) into normalized from public.hr_employee_profiles t where id=patch->>'id';
    else
      select string_agg(format('%I',key),',' order by key),
             string_agg(format('r.%I',key),',' order by key)
        into columns_sql,values_sql from jsonb_object_keys(patch) key;
      if columns_sql is null then raise exception 'No hay campos para guardar.' using errcode='22023'; end if;
      if verb='insert' then
        execute format('insert into public.%I (%s) select %s from jsonb_populate_record(null::public.%I,$1) r returning to_jsonb(%I)',
          tbl,columns_sql,values_sql,tbl,tbl) into normalized using patch;
      else
        execute format('update public.%I set (%s)=(select %s from jsonb_populate_record(null::public.%I,$1) r)
          where id::text=$2 returning to_jsonb(%I)',tbl,columns_sql,values_sql,tbl,tbl)
          into normalized using patch,rid;
      end if;
    end if;
    if normalized is null then raise exception 'No se pudo guardar el registro.' using errcode='42501'; end if;
    result := result || jsonb_build_array(jsonb_build_object('table',tbl,'action',verb,'row',normalized));
  end loop;
  insert into public.app_preserving_save_receipts(actor_id,request_id,request_body,result)
    values(auth.uid(),p_request_id,body,result);
  return result;
end;
$$;
revoke all on function public.app_commit_preserving_data(uuid,jsonb,jsonb) from public, anon;
grant execute on function public.app_commit_preserving_data(uuid,jsonb,jsonb) to authenticated;
notify pgrst, 'reload schema';
commit;
