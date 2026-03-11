do $$
declare
  v_area_logistica_id uuid;
  v_material_id uuid;
  v_commercial_code text;
  r_general record;
  r_commercial record;
begin
  select id
    into v_area_logistica_id
    from public.areas
   where upper(name) = 'LOGISTICA'
   order by created_at nulls last, id
   limit 1;

  for r_general in
    select *
    from (
      values
        ('CARTON'),
        ('CAPLE'),
        ('PAPEL'),
        ('CHATARRA'),
        ('PLASTICO'),
        ('MADERA'),
        ('METAL')
    ) as t(name)
  loop
    select id
      into v_material_id
      from public.materials
     where upper(btrim(name)) = r_general.name
     order by is_active desc, created_at nulls last, id
     limit 1;

    if v_material_id is null then
      insert into public.materials (
        name,
        area_id,
        is_active
      )
      values (
        r_general.name,
        v_area_logistica_id,
        true
      )
      returning id into v_material_id;
    else
      update public.materials
         set name = r_general.name,
             is_active = true,
             area_id = coalesce(area_id, v_area_logistica_id)
       where id = v_material_id;
    end if;
  end loop;

  for r_commercial in
    select *
    from (
      values
        ('CARTON', 'NACIONAL', 'fiber'),
        ('CARTON', 'AMERICANO', 'fiber'),
        ('CARTON', 'LIMPIO', 'fiber'),
        ('CAPLE', 'CAPLE', 'fiber'),
        ('PAPEL', 'ARCHIVO', 'fiber'),
        ('PAPEL', 'COLOR', 'fiber'),
        ('PAPEL', 'REVUELTO', 'fiber'),
        ('PAPEL', 'BLANCO SELECCION', 'fiber'),
        ('PAPEL', 'FOLLETO', 'fiber'),
        ('PAPEL', 'MAGAZINE', 'fiber'),
        ('PAPEL', 'LIBRO', 'fiber'),
        ('CHATARRA', 'BOTE GRANEL', 'metal'),
        ('CHATARRA', 'PLACA Y ESTRUCTURA LARGA', 'metal'),
        ('CHATARRA', 'PLACA Y ESTRUCTURA CORTA', 'metal'),
        ('CHATARRA', 'PESADO', 'metal'),
        ('CHATARRA', 'MIXTO', 'metal'),
        ('CHATARRA', 'RETORNO INDUSTRIAL', 'metal'),
        ('CHATARRA', 'RETORNO INDUSTRIAL ALTO RES', 'metal'),
        ('CHATARRA', 'MIXTO PARA PROCESAR', 'metal'),
        ('CHATARRA', 'PACA DE PRIMERA', 'metal'),
        ('CHATARRA', 'PACA DE SEGUNDA', 'metal'),
        ('CHATARRA', 'REBABA', 'metal'),
        ('CHATARRA', 'RETORNO INDUSTRIAL ESPECIAL', 'metal'),
        ('PLASTICO', 'UNICEL', 'polymer'),
        ('PLASTICO', 'BOLSA', 'polymer'),
        ('MADERA', 'LENA', 'other'),
        ('MADERA', 'TARIMA', 'other'),
        ('MADERA', 'PEDACERA', 'other'),
        ('METAL', 'ACERO', 'metal'),
        ('METAL', 'ACERO CON PINTURA', 'metal'),
        ('METAL', 'TRASTE', 'metal'),
        ('METAL', 'ALUMINIO PISTON', 'metal'),
        ('METAL', 'ALUMINIO BLANDO', 'metal'),
        ('METAL', 'ALUMINIO MACIZO', 'metal'),
        ('METAL', 'RIN CHICO', 'metal'),
        ('METAL', 'ALUMINIO TUBO', 'metal'),
        ('METAL', 'BRONCE', 'metal'),
        ('METAL', 'COBRE DE PRIMERA', 'metal'),
        ('METAL', 'COBRE DE SEGUNDA', 'metal'),
        ('METAL', 'COBRE CANDY', 'metal'),
        ('METAL', 'FIERRO VACIADO', 'metal'),
        ('METAL', 'PERFIL SIN PINTURA', 'metal'),
        ('METAL', 'PERFIL CON PINTURA', 'metal'),
        ('METAL', 'PLACA DE ALUMINIO', 'metal'),
        ('METAL', 'RADIADOR DE ALUMINIO', 'metal'),
        ('METAL', 'RADIADOR LATON', 'metal'),
        ('METAL', 'RADIADOR PUNTA DE COBRE', 'metal'),
        ('METAL', 'REBABA DE BRONCE', 'metal'),
        ('METAL', 'RIN GRANDE', 'metal'),
        ('METAL', 'RIN DE ALUMINIO', 'metal'),
        ('METAL', 'RADIADOR DE COBRE', 'metal'),
        ('METAL', 'TUBO', 'metal'),
        ('METAL', 'ALAMBRE DE ALUMINIO', 'metal')
    ) as t(general_name, commercial_name, family)
  loop
    select id
      into v_material_id
      from public.materials
     where upper(btrim(name)) = r_commercial.general_name
     order by is_active desc, created_at nulls last, id
     limit 1;

    if v_material_id is null then
      raise exception 'No existe el material general % para el comercial %',
        r_commercial.general_name,
        r_commercial.commercial_name;
    end if;

    v_commercial_code := regexp_replace(
      regexp_replace(r_commercial.commercial_name, '[^A-Z0-9]+', '_', 'g'),
      '^_|_$',
      '',
      'g'
    );

    if exists (
      select 1
        from public.commercial_material_catalog
       where code = v_commercial_code
    ) then
      update public.commercial_material_catalog
         set name = r_commercial.commercial_name,
             family = r_commercial.family,
             material_id = v_material_id,
             active = true
       where code = v_commercial_code;
    else
      insert into public.commercial_material_catalog (
        code,
        name,
        family,
        material_id,
        active
      )
      values (
        v_commercial_code,
        r_commercial.commercial_name,
        r_commercial.family,
        v_material_id,
        true
      );
    end if;
  end loop;
end
$$;
