begin;

alter table public.direction_shipment_plans
  add column if not exists planning_material_code text,
  add column if not exists material_scope text not null default 'commercial'
    check (material_scope in ('commercial', 'general')),
  add column if not exists quantity_unit text not null default 'PACAS'
    check (quantity_unit in ('PACAS', 'KG'));

update public.direction_shipment_plans
set
  planning_material_code = upper(btrim(coalesce(planning_material_code, commercial_material_code))),
  commercial_material_code = upper(btrim(coalesce(planning_material_code, commercial_material_code))),
  material_scope = case
    when upper(btrim(coalesce(planning_material_code, commercial_material_code))) in (
      'CHATARRA',
      'METAL',
      'PAPEL',
      'PLASTICO',
      'MADERA'
    ) then 'general'
    else 'commercial'
  end,
  quantity_unit = case
    when upper(btrim(coalesce(planning_material_code, commercial_material_code))) in (
      'CHATARRA',
      'METAL',
      'PAPEL',
      'PLASTICO',
      'MADERA'
    ) then 'KG'
    else 'PACAS'
  end
where coalesce(planning_material_code, commercial_material_code) is not null;

alter table public.direction_shipment_plans
  alter column planning_material_code set not null;

alter table public.direction_shipment_plans
  drop constraint if exists direction_shipment_plans_planning_material_code_trim_chk;

alter table public.direction_shipment_plans
  add constraint direction_shipment_plans_planning_material_code_trim_chk check (
    planning_material_code = btrim(planning_material_code)
    and length(planning_material_code) > 0
  );

create index if not exists direction_shipment_plans_planning_material_date_idx
  on public.direction_shipment_plans (planning_material_code, ship_date);

commit;
