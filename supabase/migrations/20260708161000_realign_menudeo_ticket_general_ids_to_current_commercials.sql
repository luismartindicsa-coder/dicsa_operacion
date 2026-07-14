begin;

create table if not exists public.men_tickets_general_realign_backup_20260708
as
select *
from public.men_tickets
where false;

insert into public.men_tickets_general_realign_backup_20260708
select t.*
from public.men_tickets t
join public.material_commercial_catalog_v2 c
  on c.id = t.commercial_material_id
where t.commercial_material_id is not null
  and t.general_material_id is not null
  and c.general_material_id is not null
  and t.general_material_id is distinct from c.general_material_id
  and not exists (
    select 1
    from public.men_tickets_general_realign_backup_20260708 b
    where b.id = t.id
  );

update public.men_tickets t
set general_material_id = c.general_material_id,
    updated_at = now()
from public.material_commercial_catalog_v2 c
where c.id = t.commercial_material_id
  and t.commercial_material_id is not null
  and t.general_material_id is not null
  and c.general_material_id is not null
  and t.general_material_id is distinct from c.general_material_id;

commit;
