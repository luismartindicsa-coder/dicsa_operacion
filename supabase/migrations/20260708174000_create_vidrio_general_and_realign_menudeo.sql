begin;

create table if not exists public.material_general_catalog_v2_vidrio_backup_20260708
as
select *
from public.material_general_catalog_v2
where false;

create table if not exists public.material_commercial_catalog_v2_vidrio_backup_20260708
as
select *
from public.material_commercial_catalog_v2
where false;

create table if not exists public.men_tickets_vidrio_backup_20260708
as
select *
from public.men_tickets
where false;

insert into public.material_commercial_catalog_v2_vidrio_backup_20260708
select c.*
from public.material_commercial_catalog_v2 c
where c.code = 'VIDRIO'
  and not exists (
    select 1
    from public.material_commercial_catalog_v2_vidrio_backup_20260708 b
    where b.id = c.id
  );

insert into public.men_tickets_vidrio_backup_20260708
select t.*
from public.men_tickets t
join public.material_commercial_catalog_v2 c
  on c.id = t.commercial_material_id
where c.code = 'VIDRIO'
  and not exists (
    select 1
    from public.men_tickets_vidrio_backup_20260708 b
    where b.id = t.id
  );

do $$
declare
  vidrio_general_id uuid;
  vidrio_commercial_id uuid;
begin
  insert into public.material_general_catalog_v2 (
    code,
    name,
    is_active,
    notes
  )
  select
    'VIDRIO',
    'VIDRIO',
    true,
    'Creado por reparación controlada 2026-07-08 para separar vidrio como general propio.'
  where not exists (
    select 1
    from public.material_general_catalog_v2
    where code = 'VIDRIO'
  );

  select id
    into vidrio_general_id
  from public.material_general_catalog_v2
  where code = 'VIDRIO';

  select id
    into vidrio_commercial_id
  from public.material_commercial_catalog_v2
  where code = 'VIDRIO';

  if vidrio_general_id is null or vidrio_commercial_id is null then
    raise exception 'No se pudo resolver VIDRIO general/comercial';
  end if;

  insert into public.material_general_catalog_v2_vidrio_backup_20260708
  select g.*
  from public.material_general_catalog_v2 g
  where g.id = vidrio_general_id
    and not exists (
      select 1
      from public.material_general_catalog_v2_vidrio_backup_20260708 b
      where b.id = g.id
    );

  update public.material_commercial_catalog_v2
  set general_material_id = vidrio_general_id,
      family = 'other',
      is_active = true,
      updated_at = now()
  where id = vidrio_commercial_id
    and (
      general_material_id is distinct from vidrio_general_id
      or is_active is distinct from true
    );

  update public.men_tickets
  set general_material_id = vidrio_general_id,
      updated_at = now()
  where commercial_material_id = vidrio_commercial_id
    and general_material_id is distinct from vidrio_general_id;
end
$$;

commit;
