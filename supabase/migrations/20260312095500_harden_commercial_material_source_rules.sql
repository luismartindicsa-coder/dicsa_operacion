begin;

grant select, insert, update, delete on public.commercial_material_source_rules
  to authenticated;

alter table public.commercial_material_source_rules enable row level security;

do $$
begin
  if not exists (
    select 1
      from pg_policies
     where schemaname = 'public'
       and tablename = 'commercial_material_source_rules'
       and policyname = 'commercial_material_source_rules_authenticated_all'
  ) then
    create policy commercial_material_source_rules_authenticated_all
      on public.commercial_material_source_rules
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

create or replace function public.fn_sync_commercial_material_source_rules()
returns trigger
language plpgsql
as $$
declare
  v_sources public.inv_material[] := array[]::public.inv_material[];
  v_default_source_text text;
begin
  case upper(coalesce(new.code, ''))
    when 'PACA_NACIONAL' then
      v_sources := array['CARDBOARD_BULK_NATIONAL'::public.inv_material];
    when 'PACA_AMERICANA' then
      v_sources := array[
        'CARDBOARD_BULK_AMERICAN'::public.inv_material,
        'CARDBOARD_BULK_NATIONAL'::public.inv_material
      ];
    when 'PACA_LIMPIA' then
      v_sources := array['CARDBOARD_BULK_NATIONAL'::public.inv_material];
    when 'PACA_BASURA' then
      v_sources := array['CARDBOARD_BULK_NATIONAL'::public.inv_material];
    when 'CAPLE' then
      v_sources := array['CAPLE'::public.inv_material];
    else
      select coalesce(m.inventory_material_code::text, m.inventory_general_code::text)
        into v_default_source_text
        from public.materials m
       where m.id = new.material_id
       limit 1;

      if v_default_source_text is null then
        v_default_source_text := new.inventory_material::text;
      end if;

      if v_default_source_text is not null and btrim(v_default_source_text) <> '' then
        v_sources := array[v_default_source_text::public.inv_material];
      end if;
  end case;

  update public.commercial_material_source_rules
     set is_active = false,
         updated_at = now()
   where commercial_material_code = new.code;

  if array_length(v_sources, 1) is not null then
    insert into public.commercial_material_source_rules (
      commercial_material_code,
      allowed_source_material,
      is_active
    )
    select
      new.code,
      source_material,
      true
    from unnest(v_sources) as source_material
    on conflict (commercial_material_code, allowed_source_material) do update
      set is_active = true,
          updated_at = now();
  end if;

  return new;
end
$$;

drop trigger if exists trg_sync_commercial_material_source_rules
  on public.commercial_material_catalog;

create trigger trg_sync_commercial_material_source_rules
after insert or update of code, material_id, inventory_material
on public.commercial_material_catalog
for each row
execute function public.fn_sync_commercial_material_source_rules();

update public.commercial_material_catalog
   set code = code
 where active is true;

commit;
