begin;

create table if not exists public.commercial_material_source_rules (
  id uuid primary key default gen_random_uuid(),
  commercial_material_code text not null,
  allowed_source_material public.inv_material not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint commercial_material_source_rules_unique unique (
    commercial_material_code,
    allowed_source_material
  )
);

create index if not exists commercial_material_source_rules_code_idx
  on public.commercial_material_source_rules (commercial_material_code, is_active);

do $$
declare
  v_bale_national_id uuid;
  v_bale_american_id uuid;
  v_bale_clean_id uuid;
  v_bale_trash_id uuid;
  v_caple_id uuid;
begin
  select id into v_bale_national_id
    from public.materials
   where inventory_material_code = 'BALE_NATIONAL'
   order by is_active desc, created_at nulls last, id
   limit 1;

  select id into v_bale_american_id
    from public.materials
   where inventory_material_code = 'BALE_AMERICAN'
   order by is_active desc, created_at nulls last, id
   limit 1;

  select id into v_bale_clean_id
    from public.materials
   where inventory_material_code = 'BALE_CLEAN'
   order by is_active desc, created_at nulls last, id
   limit 1;

  select id into v_bale_trash_id
    from public.materials
   where inventory_material_code = 'BALE_TRASH'
   order by is_active desc, created_at nulls last, id
   limit 1;

  select id into v_caple_id
    from public.materials
   where inventory_material_code = 'CAPLE'
   order by is_active desc, created_at nulls last, id
   limit 1;

  if v_bale_national_id is not null then
    update public.commercial_material_catalog
       set material_id = v_bale_national_id,
           inventory_material = 'BALE_NATIONAL'::public.inv_material,
           active = true
     where code = 'PACA_NACIONAL';
  end if;

  if v_bale_american_id is not null then
    update public.commercial_material_catalog
       set material_id = v_bale_american_id,
           inventory_material = 'BALE_AMERICAN'::public.inv_material,
           active = true
     where code = 'PACA_AMERICANA';
  end if;

  if v_bale_clean_id is not null then
    update public.commercial_material_catalog
       set material_id = v_bale_clean_id,
           inventory_material = 'BALE_CLEAN'::public.inv_material,
           active = true
     where code = 'PACA_LIMPIA';
  end if;

  if v_bale_trash_id is not null then
    update public.commercial_material_catalog
       set material_id = v_bale_trash_id,
           inventory_material = 'BALE_TRASH'::public.inv_material,
           active = true
     where code = 'PACA_BASURA';
  end if;

  if v_caple_id is not null then
    update public.commercial_material_catalog
       set material_id = v_caple_id,
           inventory_material = 'CAPLE'::public.inv_material,
           active = true
     where code = 'CAPLE';
  end if;
end
$$;

insert into public.commercial_material_source_rules (
  commercial_material_code,
  allowed_source_material,
  is_active
)
values
  ('PACA_NACIONAL', 'CARDBOARD_BULK_NATIONAL', true),
  ('PACA_AMERICANA', 'CARDBOARD_BULK_AMERICAN', true),
  ('PACA_AMERICANA', 'CARDBOARD_BULK_NATIONAL', true),
  ('PACA_LIMPIA', 'CARDBOARD_BULK_NATIONAL', true),
  ('PACA_BASURA', 'CARDBOARD_BULK_NATIONAL', true),
  ('CAPLE', 'CAPLE', true)
on conflict (commercial_material_code, allowed_source_material) do update
set is_active = excluded.is_active,
    updated_at = now();

commit;
