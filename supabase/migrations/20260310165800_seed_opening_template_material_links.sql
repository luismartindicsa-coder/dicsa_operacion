do $$
declare
  v_site constant text := 'DICSA';
  v_carton_material_id uuid;
  v_row record;
begin
  select id
    into v_carton_material_id
    from public.materials
   where upper(btrim(name)) = 'CARTON'
   order by is_active desc, created_at nulls last, id
   limit 1;

  if v_carton_material_id is not null then
    if exists (
      select 1
        from public.commercial_material_catalog
       where code = 'BASURA'
    ) then
      update public.commercial_material_catalog
         set name = 'BASURA',
             family = 'fiber',
             material_id = v_carton_material_id,
             active = true
       where code = 'BASURA';
    else
      insert into public.commercial_material_catalog (
        code,
        name,
        family,
        material_id,
        active
      )
      values (
        'BASURA',
        'BASURA',
        'fiber',
        v_carton_material_id,
        true
      );
    end if;
  end if;

  for v_row in
    select *
    from (
      values
        ('CARDBOARD_BULK_NATIONAL'::public.inv_material, 'NACIONAL', 10),
        ('BALE_NATIONAL'::public.inv_material, 'NACIONAL', 20),
        ('CARDBOARD_BULK_AMERICAN'::public.inv_material, 'AMERICANO', 30),
        ('BALE_AMERICAN'::public.inv_material, 'AMERICANO', 40),
        ('CARDBOARD_BULK_NATIONAL'::public.inv_material, 'LIMPIO', 50),
        ('BALE_CLEAN'::public.inv_material, 'LIMPIO', 60),
        ('CARDBOARD_BULK_NATIONAL'::public.inv_material, 'BASURA', 70),
        ('CARDBOARD_BULK_AMERICAN'::public.inv_material, 'BASURA', 80),
        ('BALE_TRASH'::public.inv_material, 'BASURA', 90),
        ('CAPLE'::public.inv_material, 'CAPLE', 100),
        ('PAPER'::public.inv_material, 'ARCHIVO', 110),
        ('PAPER'::public.inv_material, 'COLOR', 120),
        ('PAPER'::public.inv_material, 'REVUELTO', 130),
        ('PAPER'::public.inv_material, 'BLANCO_SELECCION', 140),
        ('PAPER'::public.inv_material, 'FOLLETO', 150),
        ('PAPER'::public.inv_material, 'MAGAZINE', 160),
        ('PAPER'::public.inv_material, 'LIBRO', 170),
        ('SCRAP'::public.inv_material, 'BOTE_GRANEL', 180),
        ('SCRAP'::public.inv_material, 'PLACA_Y_ESTRUCTURA_LARGA', 190),
        ('SCRAP'::public.inv_material, 'PLACA_Y_ESTRUCTURA_CORTA', 200),
        ('SCRAP'::public.inv_material, 'PESADO', 210),
        ('SCRAP'::public.inv_material, 'MIXTO', 220),
        ('SCRAP'::public.inv_material, 'RETORNO_INDUSTRIAL', 230),
        ('SCRAP'::public.inv_material, 'RETORNO_INDUSTRIAL_ALTO_RES', 240),
        ('SCRAP'::public.inv_material, 'MIXTO_PARA_PROCESAR', 250),
        ('SCRAP'::public.inv_material, 'PACA_DE_PRIMERA', 260),
        ('SCRAP'::public.inv_material, 'PACA_DE_SEGUNDA', 270),
        ('SCRAP'::public.inv_material, 'REBABA', 280),
        ('SCRAP'::public.inv_material, 'RETORNO_INDUSTRIAL_ESPECIAL', 290),
        ('PLASTIC'::public.inv_material, 'UNICEL', 300),
        ('PLASTIC'::public.inv_material, 'BOLSA', 310),
        ('WOOD'::public.inv_material, 'LENA', 320),
        ('WOOD'::public.inv_material, 'TARIMA', 330),
        ('WOOD'::public.inv_material, 'PEDACERA', 340),
        ('METAL'::public.inv_material, 'ACERO', 350),
        ('METAL'::public.inv_material, 'ACERO_CON_PINTURA', 360),
        ('METAL'::public.inv_material, 'TRASTE', 370),
        ('METAL'::public.inv_material, 'ALUMINIO_PISTON', 380),
        ('METAL'::public.inv_material, 'ALUMINIO_BLANDO', 390),
        ('METAL'::public.inv_material, 'ALUMINIO_MACIZO', 400),
        ('METAL'::public.inv_material, 'RIN_CHICO', 410),
        ('METAL'::public.inv_material, 'ALUMINIO_TUBO', 420),
        ('METAL'::public.inv_material, 'BRONCE', 430),
        ('METAL'::public.inv_material, 'COBRE_DE_PRIMERA', 440),
        ('METAL'::public.inv_material, 'COBRE_DE_SEGUNDA', 450),
        ('METAL'::public.inv_material, 'COBRE_CANDY', 460),
        ('METAL'::public.inv_material, 'FIERRO_VACIADO', 470),
        ('METAL'::public.inv_material, 'PERFIL_SIN_PINTURA', 480),
        ('METAL'::public.inv_material, 'PERFIL_CON_PINTURA', 490),
        ('METAL'::public.inv_material, 'PLACA_DE_ALUMINIO', 500),
        ('METAL'::public.inv_material, 'RADIADOR_DE_ALUMINIO', 510),
        ('METAL'::public.inv_material, 'RADIADOR_LATON', 520),
        ('METAL'::public.inv_material, 'RADIADOR_PUNTA_DE_COBRE', 530),
        ('METAL'::public.inv_material, 'REBABA_DE_BRONCE', 540),
        ('METAL'::public.inv_material, 'RIN_GRANDE', 550),
        ('METAL'::public.inv_material, 'RIN_DE_ALUMINIO', 560),
        ('METAL'::public.inv_material, 'RADIADOR_DE_COBRE', 570),
        ('METAL'::public.inv_material, 'TUBO', 580),
        ('METAL'::public.inv_material, 'ALAMBRE_DE_ALUMINIO', 590)
    ) as t(material, commercial_material_code, sort_order)
  loop
    if exists (
      select 1
        from public.inventory_opening_templates
       where site = v_site
         and material = v_row.material
         and commercial_material_code = v_row.commercial_material_code
    ) then
      update public.inventory_opening_templates
         set sort_order = v_row.sort_order,
             is_active = true
       where site = v_site
         and material = v_row.material
         and commercial_material_code = v_row.commercial_material_code;
    else
      insert into public.inventory_opening_templates (
        site,
        material,
        commercial_material_code,
        sort_order,
        is_active
      )
      values (
        v_site,
        v_row.material,
        v_row.commercial_material_code,
        v_row.sort_order,
        true
      );
    end if;
  end loop;
end
$$;
