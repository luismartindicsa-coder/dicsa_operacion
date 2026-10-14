begin;

-- Extend the existing role constraint without removing any deployed roles.
do $$
declare
  allowed_roles text;
begin
  select pg_get_expr(conbin, conrelid) into strict allowed_roles
  from pg_constraint
  where conrelid = 'public.profiles'::regclass
    and conname = 'profiles_role_check';

  alter table public.profiles drop constraint profiles_role_check;
  execute format(
    'alter table public.profiles add constraint profiles_role_check check ((%s) or role = %L)',
    allowed_roles, 'bascula'
  );
end $$;

-- Use the existing login. Preserve its password, sessions and active status.
insert into public.profiles(user_id, role, is_active)
select id, 'bascula', true from auth.users
where lower(trim(email)) = 'bascula@dicsamx.com'
on conflict(user_id) do update set role = excluded.role;

do $$
begin
  if exists (
    select 1 from auth.users u join public.profiles p on p.user_id = u.id
    where lower(trim(u.email)) = 'bascula@dicsamx.com' and p.role = 'bascula'
  ) then
    raise notice 'Cuenta bascula@dicsamx.com asignada al perfil bascula.';
  else
    raise notice 'El rol bascula está disponible; la cuenta aún no existe en este entorno.';
  end if;
end $$;

notify pgrst, 'reload schema';
commit;
