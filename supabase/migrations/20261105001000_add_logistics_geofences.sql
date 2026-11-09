begin;

create function public.valid_logistics_geofence_points(points jsonb, shape smallint)
returns boolean language plpgsql immutable set search_path='' as $$
begin
  if points is null or jsonb_typeof(points)<>'array' then return false; end if;
  if jsonb_array_length(points)>10000 or
    jsonb_array_length(points)<(case when shape=3 then 1 when shape=2 then 3 else 2 end) or
    (shape=3 and jsonb_array_length(points)<>1) then return false; end if;
  return not exists(select 1 from jsonb_array_elements(points) p
    where jsonb_typeof(p)<>'object' or jsonb_typeof(p->'lat') is distinct from 'number'
      or jsonb_typeof(p->'lng') is distinct from 'number'
      or (p->>'lat')::double precision not between -90 and 90
      or (p->>'lng')::double precision not between -180 and 180);
exception when others then return false;
end; $$;

create table public.logistics_geofences (
  resource_id text not null check(resource_id ~ '^[0-9]+$'),
  geofence_id text not null check(geofence_id ~ '^[0-9]+$'),
  provider_name text not null check(length(btrim(provider_name))>0),
  shape_type smallint not null check(shape_type in (1,2,3)),
  width_m double precision not null check(width_m>=0 and width_m<'Infinity'::double precision),
  points jsonb,
  provider_created_at bigint not null check(provider_created_at>=0),
  provider_modified_at bigint not null check(provider_modified_at>=0),
  provider_visible boolean not null default true,
  observed_at timestamptz not null default now(),
  site_id uuid references public.sites(id) on delete set null,
  classification text not null default 'pending' check(classification in ('pending','company','base','other','ignored')),
  link_version bigint not null default 0,
  link_updated_at timestamptz,
  linked_by uuid,
  primary key(resource_id,geofence_id),
  check((provider_visible and public.valid_logistics_geofence_points(points,shape_type) and (shape_type<>3 or width_m>0))
    or (not provider_visible and points is null)),
  check(site_id is null or classification='company')
);
create index logistics_geofences_site_idx on public.logistics_geofences(site_id);

create table public.logistics_geofence_sync_state (
  singleton boolean primary key default true check(singleton),
  status text not null default 'pending' check(status in ('pending','ok','error')),
  last_attempt_at timestamptz, last_success_at timestamptz, error_code text,
  run_id uuid, lease_until timestamptz
);
insert into public.logistics_geofence_sync_state(singleton) values(true);

alter table public.logistics_geofences enable row level security;
alter table public.logistics_geofence_sync_state enable row level security;
revoke all on public.logistics_geofences,public.logistics_geofence_sync_state from anon,authenticated;
grant select on public.logistics_geofences,public.logistics_geofence_sync_state to authenticated;
grant all on public.logistics_geofences,public.logistics_geofence_sync_state to service_role;
create policy logistics_geofences_read on public.logistics_geofences for select to authenticated
  using ((select public.can_view_logistics_gps()));
create policy logistics_geofences_sync_read on public.logistics_geofence_sync_state for select to authenticated
  using ((select public.can_view_logistics_gps()));

create function public.claim_logistics_geofence_sync() returns uuid
language plpgsql security definer set search_path='' as $$
declare claimed uuid;
begin
  update public.logistics_geofence_sync_state
    set run_id=gen_random_uuid(),lease_until=now()+interval '90 seconds',last_attempt_at=now()
    where singleton and (lease_until is null or lease_until<now())
      and (last_attempt_at is null or last_attempt_at<now()-interval '5 minutes')
    returning run_id into claimed;
  return claimed;
end; $$;

create function public.complete_logistics_geofence_sync(p_run_id uuid,p_geofences jsonb,p_error text default null)
returns boolean language plpgsql security definer set search_path='' as $$
declare started timestamptz;
begin
  select last_attempt_at into started from public.logistics_geofence_sync_state
    where singleton and run_id=p_run_id for update;
  if not found then return false; end if;
  if p_error is not null then
    if p_error not in ('not_configured','authorization','provider_unavailable','invalid_response','storage') then
      raise exception 'Invalid geofence error'; end if;
    update public.logistics_geofence_sync_state set status='error',error_code=p_error,run_id=null,lease_until=null where singleton;
    return true;
  end if;
  if p_geofences is null or jsonb_typeof(p_geofences)<>'array' then raise exception 'Invalid geofence snapshot'; end if;
  if jsonb_array_length(p_geofences)>10000 then raise exception 'Geofence snapshot too large'; end if;
  if exists(select 1 from jsonb_array_elements(p_geofences) p
    where jsonb_typeof(p)<>'object' or coalesce(p->>'resource_id','')!~'^[0-9]+$'
      or coalesce(p->>'geofence_id','')!~'^[0-9]+$') then raise exception 'Invalid geofence identity'; end if;
  if (select count(*)<>count(distinct (p->>'resource_id',p->>'geofence_id')) from jsonb_array_elements(p_geofences) p) then
    raise exception 'Duplicate geofence'; end if;
  insert into public.logistics_geofences as current(resource_id,geofence_id,provider_name,shape_type,width_m,points,
    provider_created_at,provider_modified_at,observed_at,provider_visible)
    select x.resource_id,x.geofence_id,x.provider_name,x.shape_type,x.width_m,x.points,
      x.provider_created_at,x.provider_modified_at,started,true
    from jsonb_to_recordset(p_geofences) as x(resource_id text,geofence_id text,provider_name text,shape_type smallint,
      width_m double precision,points jsonb,provider_created_at bigint,provider_modified_at bigint)
    on conflict(resource_id,geofence_id) do update set provider_name=excluded.provider_name,
      shape_type=excluded.shape_type,width_m=excluded.width_m,points=excluded.points,
      provider_created_at=excluded.provider_created_at,provider_modified_at=excluded.provider_modified_at,
      observed_at=excluded.observed_at,provider_visible=true,
      site_id=case when current.provider_created_at=excluded.provider_created_at then current.site_id else null end,
      classification=case when current.provider_created_at=excluded.provider_created_at then current.classification else 'pending' end,
      link_version=current.link_version+case when current.provider_created_at=excluded.provider_created_at then 0 else 1 end,
      linked_by=case when current.provider_created_at=excluded.provider_created_at then current.linked_by else null end;
  update public.logistics_geofences g set provider_visible=false,points=null
    where not exists(select 1 from jsonb_array_elements(p_geofences) p
      where p->>'resource_id'=g.resource_id and p->>'geofence_id'=g.geofence_id);
  update public.logistics_geofence_sync_state set status='ok',last_success_at=started,
    error_code=null,run_id=null,lease_until=null where singleton;
  return true;
end; $$;

-- Only the reviewed association is editable. Provider geometry is server-owned.
create function public.link_logistics_geofence(p_resource_id text,p_geofence_id text,p_site_id uuid,
  p_classification text,p_expected_version bigint) returns bigint
language plpgsql security definer set search_path='' as $$
declare version bigint;
begin
  if not public.can_view_logistics_gps() then raise exception 'GPS access denied' using errcode='42501'; end if;
  if p_classification is null or p_classification not in ('pending','company','base','other','ignored')
    or (p_classification='company' and p_site_id is null)
    or (p_classification<>'company' and p_site_id is not null) then raise exception 'Invalid geofence link'; end if;
  if p_site_id is not null and not exists(select 1 from public.sites where id=p_site_id and is_active and type='cliente') then
    raise exception 'Company not available'; end if;
  update public.logistics_geofences set site_id=p_site_id,classification=p_classification,
    link_version=link_version+1,link_updated_at=now(),linked_by=auth.uid()
    where resource_id=p_resource_id and geofence_id=p_geofence_id and link_version=p_expected_version and provider_visible
    returning link_version into version;
  if not found then raise exception 'Geofence changed; reload before saving' using errcode='40001'; end if;
  return version;
end; $$;

revoke all on function public.claim_logistics_geofence_sync() from public,anon,authenticated;
revoke all on function public.complete_logistics_geofence_sync(uuid,jsonb,text) from public,anon,authenticated;
revoke all on function public.link_logistics_geofence(text,text,uuid,text,bigint) from public,anon;
grant execute on function public.claim_logistics_geofence_sync() to service_role;
grant execute on function public.complete_logistics_geofence_sync(uuid,jsonb,text) to service_role;
grant execute on function public.link_logistics_geofence(text,text,uuid,text,bigint) to authenticated;
commit;
