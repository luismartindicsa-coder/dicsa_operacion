begin;

create table if not exists public.material_general_catalog_v2_menudeo_reclass_backup_20260708
as
select *
from public.material_general_catalog_v2
where false;

create table if not exists public.material_commercial_catalog_v2_menudeo_reclass_backup_20260708
as
select *
from public.material_commercial_catalog_v2
where false;

create table if not exists public.men_tickets_menudeo_reclass_backup_20260708
as
select *
from public.men_tickets
where false;

create table if not exists public.inventory_movements_v2_menudeo_reclass_backup_20260708
as
select *
from public.inventory_movements_v2
where false;

insert into public.material_general_catalog_v2_menudeo_reclass_backup_20260708
select g.*
from public.material_general_catalog_v2 g
where g.code in (
  'TARIMA_DE_PLASTICO',
  'REJAS',
  'POLIFON',
  'PLASTICO_DURO',
  'MADERA_GRANEL',
  'GARRAFA_GRANDE',
  'GARRAFA_CHICA',
  'CABLE'
)
and not exists (
  select 1
  from public.material_general_catalog_v2_menudeo_reclass_backup_20260708 b
  where b.id = g.id
);

insert into public.material_commercial_catalog_v2_menudeo_reclass_backup_20260708
select c.*
from public.material_commercial_catalog_v2 c
where c.code in (
  'TARIMA_DE_PLASTICO',
  'REJAS',
  'POLIFON',
  'PLASTICO_DURO',
  'MADERA_GRANEL',
  'GARRAFA_GRANDE',
  'GARRAFA_CHICA',
  'CABLE'
)
and not exists (
  select 1
  from public.material_commercial_catalog_v2_menudeo_reclass_backup_20260708 b
  where b.id = c.id
);

insert into public.men_tickets_menudeo_reclass_backup_20260708
select t.*
from public.men_tickets t
where t.general_material_id in (
  select id
  from public.material_general_catalog_v2
  where code in (
    'TARIMA_DE_PLASTICO',
    'REJAS',
    'POLIFON',
    'PLASTICO_DURO',
    'MADERA_GRANEL',
    'GARRAFA_GRANDE',
    'GARRAFA_CHICA',
    'CABLE'
  )
)
and not exists (
  select 1
  from public.men_tickets_menudeo_reclass_backup_20260708 b
  where b.id = t.id
);

insert into public.inventory_movements_v2_menudeo_reclass_backup_20260708
select m.*
from public.inventory_movements_v2 m
where m.general_material_id in (
  select id
  from public.material_general_catalog_v2
  where code in (
    'TARIMA_DE_PLASTICO',
    'REJAS',
    'POLIFON',
    'PLASTICO_DURO',
    'MADERA_GRANEL',
    'GARRAFA_GRANDE',
    'GARRAFA_CHICA',
    'CABLE'
  )
)
and not exists (
  select 1
  from public.inventory_movements_v2_menudeo_reclass_backup_20260708 b
  where b.id = m.id
);

do $$
declare
  plastico_general_id uuid;
  metal_general_id uuid;
  madera_general_id uuid;
  bad_tarima_general_id uuid;
  bad_rejas_general_id uuid;
  bad_polifon_general_id uuid;
  bad_plastico_duro_general_id uuid;
  bad_madera_granel_general_id uuid;
  bad_garrafa_grande_general_id uuid;
  bad_garrafa_chica_general_id uuid;
  bad_cable_general_id uuid;
  tarima_commercial_id uuid;
  rejas_commercial_id uuid;
  polifon_commercial_id uuid;
  plastico_duro_commercial_id uuid;
  madera_granel_commercial_id uuid;
  garrafa_grande_commercial_id uuid;
  garrafa_chica_commercial_id uuid;
  cable_commercial_id uuid;
begin
  select id into plastico_general_id
  from public.material_general_catalog_v2
  where code = 'PLASTICO';

  select id into metal_general_id
  from public.material_general_catalog_v2
  where code = 'METAL';

  select id into madera_general_id
  from public.material_general_catalog_v2
  where code = 'MADERA';

  select id into bad_tarima_general_id
  from public.material_general_catalog_v2
  where code = 'TARIMA_DE_PLASTICO';

  select id into bad_rejas_general_id
  from public.material_general_catalog_v2
  where code = 'REJAS';

  select id into bad_polifon_general_id
  from public.material_general_catalog_v2
  where code = 'POLIFON';

  select id into bad_plastico_duro_general_id
  from public.material_general_catalog_v2
  where code = 'PLASTICO_DURO';

  select id into bad_madera_granel_general_id
  from public.material_general_catalog_v2
  where code = 'MADERA_GRANEL';

  select id into bad_garrafa_grande_general_id
  from public.material_general_catalog_v2
  where code = 'GARRAFA_GRANDE';

  select id into bad_garrafa_chica_general_id
  from public.material_general_catalog_v2
  where code = 'GARRAFA_CHICA';

  select id into bad_cable_general_id
  from public.material_general_catalog_v2
  where code = 'CABLE';

  if plastico_general_id is null or metal_general_id is null or madera_general_id is null then
    raise exception 'No se encontraron los generales canónicos requeridos';
  end if;

  insert into public.material_commercial_catalog_v2 (
    code,
    name,
    family,
    general_material_id,
    classification_kind,
    flow_scope,
    tracks_patio_stock,
    allows_direct_entry,
    allows_transformation_output,
    allows_sale,
    is_active,
    notes
  )
  select
    'POLIFON',
    'POLIFON',
    'polymer',
    plastico_general_id,
    'classified_stock',
    'BOTH',
    true,
    true,
    true,
    true,
    true,
    'Creado por reparación controlada 2026-07-08 para reclasificar material general impropio.'
  where not exists (
    select 1
    from public.material_commercial_catalog_v2
    where code = 'POLIFON'
  );

  insert into public.material_commercial_catalog_v2 (
    code,
    name,
    family,
    general_material_id,
    classification_kind,
    flow_scope,
    tracks_patio_stock,
    allows_direct_entry,
    allows_transformation_output,
    allows_sale,
    is_active,
    notes
  )
  select
    'PLASTICO_DURO',
    'PLASTICO DURO',
    'plastic',
    plastico_general_id,
    'classified_stock',
    'BOTH',
    true,
    true,
    true,
    true,
    true,
    'Creado por reparación controlada 2026-07-08 para reclasificar material general impropio.'
  where not exists (
    select 1
    from public.material_commercial_catalog_v2
    where code = 'PLASTICO_DURO'
  );

  insert into public.material_commercial_catalog_v2 (
    code,
    name,
    family,
    general_material_id,
    classification_kind,
    flow_scope,
    tracks_patio_stock,
    allows_direct_entry,
    allows_transformation_output,
    allows_sale,
    is_active,
    notes
  )
  select
    'MADERA_GRANEL',
    'MADERA GRANEL',
    'other',
    madera_general_id,
    'classified_stock',
    'BOTH',
    true,
    true,
    true,
    true,
    true,
    'Creado por reparación controlada 2026-07-08 para reclasificar material general impropio.'
  where not exists (
    select 1
    from public.material_commercial_catalog_v2
    where code = 'MADERA_GRANEL'
  );

  select id into tarima_commercial_id
  from public.material_commercial_catalog_v2
  where code = 'TARIMA_DE_PLASTICO';

  select id into rejas_commercial_id
  from public.material_commercial_catalog_v2
  where code = 'REJAS';

  select id into polifon_commercial_id
  from public.material_commercial_catalog_v2
  where code = 'POLIFON';

  select id into plastico_duro_commercial_id
  from public.material_commercial_catalog_v2
  where code = 'PLASTICO_DURO';

  select id into madera_granel_commercial_id
  from public.material_commercial_catalog_v2
  where code = 'MADERA_GRANEL';

  select id into garrafa_grande_commercial_id
  from public.material_commercial_catalog_v2
  where code = 'GARRAFA_GRANDE';

  select id into garrafa_chica_commercial_id
  from public.material_commercial_catalog_v2
  where code = 'GARRAFA_CHICA';

  select id into cable_commercial_id
  from public.material_commercial_catalog_v2
  where code = 'CABLE';

  if tarima_commercial_id is null
     or rejas_commercial_id is null
     or polifon_commercial_id is null
     or plastico_duro_commercial_id is null
     or madera_granel_commercial_id is null
     or garrafa_grande_commercial_id is null
     or garrafa_chica_commercial_id is null
     or cable_commercial_id is null then
    raise exception 'No se pudo asegurar el catálogo comercial esperado para la reparación';
  end if;

  update public.material_commercial_catalog_v2
  set general_material_id = plastico_general_id,
      family = 'plastic',
      is_active = true,
      updated_at = now()
  where id in (
    tarima_commercial_id,
    garrafa_grande_commercial_id,
    garrafa_chica_commercial_id,
    polifon_commercial_id,
    plastico_duro_commercial_id
  )
    and (
      general_material_id is distinct from plastico_general_id
      or family is distinct from 'plastic'
      or is_active is distinct from true
    );

  update public.material_commercial_catalog_v2
  set general_material_id = madera_general_id,
      is_active = true,
      updated_at = now()
  where id = madera_granel_commercial_id
    and (
      general_material_id is distinct from madera_general_id
      or is_active is distinct from true
    );

  update public.material_commercial_catalog_v2
  set general_material_id = metal_general_id,
      family = 'metal',
      is_active = true,
      updated_at = now()
  where id in (rejas_commercial_id, cable_commercial_id)
    and (
      general_material_id is distinct from metal_general_id
      or family is distinct from 'metal'
      or is_active is distinct from true
    );

  update public.men_tickets
  set general_material_id = case
        when commercial_material_id = rejas_commercial_id then metal_general_id
        when commercial_material_id = cable_commercial_id then metal_general_id
        when commercial_material_id = tarima_commercial_id then plastico_general_id
        when commercial_material_id = garrafa_grande_commercial_id then plastico_general_id
        when commercial_material_id = garrafa_chica_commercial_id then plastico_general_id
        when commercial_material_id = polifon_commercial_id then plastico_general_id
        when commercial_material_id = plastico_duro_commercial_id then plastico_general_id
        when commercial_material_id = madera_granel_commercial_id then madera_general_id
        else general_material_id
      end,
      updated_at = now()
  where commercial_material_id in (
    tarima_commercial_id,
    rejas_commercial_id,
    polifon_commercial_id,
    plastico_duro_commercial_id,
    madera_granel_commercial_id,
    garrafa_grande_commercial_id,
    garrafa_chica_commercial_id,
    cable_commercial_id
  )
    and general_material_id in (
      bad_tarima_general_id,
      bad_rejas_general_id,
      bad_polifon_general_id,
      bad_plastico_duro_general_id,
      bad_madera_granel_general_id,
      bad_garrafa_grande_general_id,
      bad_garrafa_chica_general_id,
      bad_cable_general_id
    );

  update public.inventory_movements_v2
  set general_material_id = plastico_general_id,
      source_commercial_material_id = garrafa_chica_commercial_id,
      updated_at = now()
  where general_material_id = bad_garrafa_chica_general_id;

  update public.material_general_catalog_v2
  set is_active = false,
      updated_at = now()
  where id in (
    bad_tarima_general_id,
    bad_rejas_general_id,
    bad_polifon_general_id,
    bad_plastico_duro_general_id,
    bad_madera_granel_general_id,
    bad_garrafa_grande_general_id,
    bad_garrafa_chica_general_id,
    bad_cable_general_id
  )
    and is_active is distinct from false;
end
$$;

commit;
