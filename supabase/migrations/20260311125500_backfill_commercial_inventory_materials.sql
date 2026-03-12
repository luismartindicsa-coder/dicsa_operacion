begin;

do $$
begin
  update public.commercial_material_catalog cmc
     set inventory_material = m.inventory_material_code,
         active = true
    from public.materials m
   where m.id = cmc.material_id
     and m.inventory_material_code is not null
     and (
       cmc.inventory_material is null
       or cmc.inventory_material::text <> m.inventory_material_code::text
     );

  update public.commercial_material_catalog
     set inventory_material = case upper(coalesce(code, ''))
       when 'CARTON_NACIONAL' then 'CARDBOARD_BULK_NATIONAL'::public.inv_material
       when 'CARTON_AMERICANO' then 'CARDBOARD_BULK_AMERICAN'::public.inv_material
       when 'PACA_NACIONAL' then 'BALE_NATIONAL'::public.inv_material
       when 'PACA_AMERICANA' then 'BALE_AMERICAN'::public.inv_material
       when 'PACA_LIMPIA' then 'BALE_CLEAN'::public.inv_material
       when 'PACA_BASURA' then 'BALE_TRASH'::public.inv_material
       when 'BASURA' then 'BALE_TRASH'::public.inv_material
       when 'LODOS' then 'BALE_TRASH'::public.inv_material
       when 'CAPLE' then 'CAPLE'::public.inv_material
       else inventory_material
     end,
         active = true
   where upper(coalesce(code, '')) in (
     'CARTON_NACIONAL',
     'CARTON_AMERICANO',
     'PACA_NACIONAL',
     'PACA_AMERICANA',
     'PACA_LIMPIA',
     'PACA_BASURA',
     'BASURA',
     'LODOS',
     'CAPLE'
   );

  update public.commercial_material_catalog cmc
     set inventory_material = case upper(btrim(coalesce(m.name, '')))
       when 'PAPEL' then 'PAPER'::public.inv_material
       when 'CHATARRA' then 'SCRAP'::public.inv_material
       when 'PLASTICO' then 'PLASTIC'::public.inv_material
       when 'MADERA' then 'WOOD'::public.inv_material
       when 'METAL' then 'METAL'::public.inv_material
       when 'BASURA' then 'BALE_TRASH'::public.inv_material
       else cmc.inventory_material
     end,
         active = true
    from public.materials m
   where m.id = cmc.material_id
     and (
       cmc.inventory_material is null
       or cmc.inventory_material::text = ''
     )
     and upper(btrim(coalesce(m.name, ''))) in (
       'PAPEL',
       'CHATARRA',
       'PLASTICO',
       'MADERA',
       'METAL',
       'BASURA'
     );
end
$$;

commit;
