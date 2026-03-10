begin;

alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check
  check (
    role = any (
      array[
        'admin'::text,
        'ops_manager'::text,
        'services'::text,
        'fleet'::text,
        'fuel'::text,
        'viewer'::text,
        'direccion'::text
      ]
    )
  );

do $$
declare
  v_user_id uuid;
begin
  select id
    into v_user_id
  from auth.users
  where lower(email) = 'direccion@dicsamx.com'
  limit 1;

  if v_user_id is null then
    raise notice 'No se encontro usuario auth.users para direccion@dicsamx.com';
    return;
  end if;

  update public.profiles
     set role = 'direccion',
         is_active = true
   where user_id = v_user_id;

  if not found then
    begin
      insert into public.profiles (user_id, role, is_active)
      values (v_user_id, 'direccion', true);
    exception
      when others then
        raise notice
          'No se pudo insertar profile para direccion@dicsamx.com; revisa columnas requeridas adicionales en public.profiles';
    end;
  end if;
end
$$;

commit;
