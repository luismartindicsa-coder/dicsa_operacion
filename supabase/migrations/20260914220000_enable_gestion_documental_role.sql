begin;

-- Preserve existing roles and add an area-specific role, without admin access.
alter table public.profiles drop constraint profiles_role_check;
alter table public.profiles add constraint profiles_role_check check (role in (
  'admin','ops_manager','services','fleet','fuel','viewer','direccion',
  'desarrollo_comercial','gestion_documental'
));

create or replace function public.documental_can_manage() returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists(select 1 from public.profiles p where p.user_id=auth.uid()
    and p.is_active and (
      lower(p.role::text) in ('gestion_documental','direccion','direction','direccion_general','auxiliar_direccion','admin')
      or lower(p.role::text) like 'direccion\_%' escape '\'
      or lower(p.role::text) like '%\_direccion' escape '\'
    ));
$$;

-- Assign only the account already created for this area. No auth user is created
-- and no password, email confirmation or session is changed by this migration.
insert into public.profiles(user_id,role,is_active)
select id,'gestion_documental',true from auth.users
where lower(email)='gestion@dicsamx.com'
on conflict(user_id) do update set role=excluded.role,is_active=excluded.is_active;

notify pgrst,'reload schema';
commit;
