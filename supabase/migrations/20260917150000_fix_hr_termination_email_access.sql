begin;

-- AuthAccess accepts the designated RH / Dirección accounts even when no
-- profiles row exists. Resolve the account on the server and keep an explicit
-- inactive profile blocked, including accounts authorized by email.
create or replace function public.hr_can_access_termination_calculations()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from auth.users u
    left join public.profiles p on p.user_id = u.id
    cross join lateral (
      select regexp_replace(translate(lower(trim(coalesce(p.role::text, ''))), 'áéíóú', 'aeiou'), '[[:space:]-]+', '_', 'g') as role
    ) normalized
    where u.id = auth.uid() and coalesce(p.is_active, true) and (
      lower(trim(coalesce(u.email, ''))) in ('rh@dicsamx.com', 'direccion@dicsamx.com')
      or normalized.role in ('rh', 'rrhh', 'human_resources', 'recursos_humanos', 'nominas', 'payroll', 'direccion', 'direction', 'auxiliar_direccion', 'direccion_general')
      or normalized.role ~ '^(rh_|human_resources_|recursos_humanos_|direccion_)'
      or normalized.role ~ '(_rh|_human_resources|_recursos_humanos|_direccion)$'
      or normalized.role like '%direction%'
    )
  );
$$;

revoke all on function public.hr_can_access_termination_calculations() from public, anon;
grant execute on function public.hr_can_access_termination_calculations() to authenticated;

notify pgrst, 'reload schema';
commit;
