-- Catalogo Compras derivado desde CSV legacy
begin;


-- Normaliza familia/categoria OTRO -> OTROS en datos existentes
update public.compras_material_catalog
set
  category = case when category = 'OTRO' then 'OTROS' else category end,
  family = case when family = 'OTRO' then 'OTROS' else family end
where category = 'OTRO' or family = 'OTRO';

create temporary table tmp_import_compras_counterparties (
  id text,
  code text,
  name text,
  contact text,
  is_active boolean,
  notes text
) on commit drop;

insert into tmp_import_compras_counterparties (
  id,
  code,
  name,
  contact,
  is_active,
  notes
) values
  ('cp_import_acroma', 'ACROMA', 'ACROMA', null, true, null),
  ('cp_import_adolfo_gutierrez', 'ADOLFO_GUTIERREZ', 'ADOLFO GUTIERREZ', null, true, null),
  ('cp_import_avon', 'AVON', 'AVON', null, true, null),
  ('cp_import_cedis', 'CEDIS', 'CEDIS', null, true, null),
  ('cp_import_decasa', 'DECASA', 'DECASA', null, true, null),
  ('cp_import_dimeca', 'DIMECA', 'DIMECA', null, true, null),
  ('cp_import_emilio_sandoval', 'EMILIO_SANDOVAL', 'EMILIO SANDOVAL', null, true, null),
  ('cp_import_facturas', 'FACTURAS', 'FACTURAS', null, true, null),
  ('cp_import_fernando_rubio', 'FERNANDO_RUBIO', 'FERNANDO RUBIO', null, true, null),
  ('cp_import_gescrap', 'GESCRAP', 'GESCRAP', null, true, null),
  ('cp_import_gkn_forja', 'GKN_FORJA', 'GKN FORJA', null, true, null),
  ('cp_import_gkn_maquinados', 'GKN_MAQUINADOS', 'GKN MAQUINADOS', null, true, null),
  ('cp_import_gkn_villagran', 'GKN_VILLAGRAN', 'GKN VILLAGRAN', null, true, null),
  ('cp_import_grupo_rescrain', 'GRUPO_RESCRAIN', 'GRUPO RESCRAIN', null, true, null),
  ('cp_import_hanwa', 'HANWA', 'HANWA', null, true, null),
  ('cp_import_jose_luis_muniz', 'JOSE_LUIS_MUNIZ', 'JOSE LUIS MUNIZ', null, true, null),
  ('cp_import_juan_solis', 'JUAN_SOLIS', 'JUAN SOLIS', null, true, null),
  ('cp_import_ks', 'KS', 'KS', null, true, null),
  ('cp_import_licbox', 'LICBOX', 'LICBOX', null, true, null),
  ('cp_import_lourdes_coronilla', 'LOURDES_CORONILLA', 'LOURDES CORONILLA', null, true, null),
  ('cp_import_martin_guzman', 'MARTIN_GUZMAN', 'MARTIN GUZMAN', null, true, null),
  ('cp_import_mauricio_alcala', 'MAURICIO_ALCALA', 'MAURICIO ALCALA', null, true, null),
  ('cp_import_mauricio_garcia', 'MAURICIO_GARCIA', 'MAURICIO GARCIA', null, true, null),
  ('cp_import_migavid', 'MIGAVID', 'MIGAVID', null, true, null),
  ('cp_import_migue_apaseo', 'MIGUE_APASEO', 'MIGUE APASEO', null, true, null),
  ('cp_import_miguel_ayala', 'MIGUEL_AYALA', 'MIGUEL AYALA', null, true, null),
  ('cp_import_miguel_sanchez', 'MIGUEL_SANCHEZ', 'MIGUEL SANCHEZ', null, true, null),
  ('cp_import_monroe', 'MONROE', 'MONROE', null, true, null),
  ('cp_import_pirineos', 'PIRINEOS', 'PIRINEOS', null, true, null),
  ('cp_import_recicla_metal', 'RECICLA_METAL', 'RECICLA METAL', null, true, null),
  ('cp_import_ricardo_garcia_mendieta', 'RICARDO_GARCIA_MENDIETA', 'RICARDO GARCIA MENDIETA', null, true, null),
  ('cp_import_rocio_carvajal', 'ROCIO_CARVAJAL', 'ROCIO CARVAJAL', null, true, null),
  ('cp_import_rodolfo_vera', 'RODOLFO_VERA', 'RODOLFO VERA', null, true, null),
  ('cp_import_ryobi', 'RYOBI', 'RYOBI', null, true, null),
  ('cp_import_sanoh', 'SANOH', 'SANOH', null, true, null),
  ('cp_import_setexmes', 'SETEXMES', 'SETEXMES', null, true, null),
  ('cp_import_sierra_servicios_de_perforacion', 'SIERRA_SERVICIOS_DE_PERFORACION', 'SIERRA SERVICIOS DE PERFORACION', null, true, null),
  ('cp_import_tenneco', 'TENNECO', 'TENNECO', null, true, null),
  ('cp_import_victor_alcala', 'VICTOR_ALCALA', 'VICTOR ALCALA', null, true, null),
  ('cp_import_victor_garcia', 'VICTOR_GARCIA', 'VICTOR GARCIA', null, true, null),
  ('cp_import_whirlpool', 'WHIRLPOOL', 'WHIRLPOOL', null, true, null),
  ('cp_import_yorozu', 'YOROZU', 'YOROZU', null, true, null);

insert into public.compras_counterparties (
  id,
  code,
  name,
  contact,
  is_active,
  notes
)
select
  src.id,
  src.code,
  src.name,
  src.contact,
  src.is_active,
  src.notes
from tmp_import_compras_counterparties src
where not exists (
  select 1
  from public.compras_counterparties dst
  where upper(dst.name) = upper(src.name)
);

update public.compras_counterparties dst
set
  code = src.code,
  contact = src.contact,
  is_active = src.is_active,
  notes = src.notes
from tmp_import_compras_counterparties src
where upper(dst.name) = upper(src.name);

create temporary table tmp_import_compras_materials (
  id text,
  code text,
  level text,
  name text,
  unit text,
  category text,
  family text,
  general_material_id text,
  is_active boolean,
  notes text
) on commit drop;

insert into tmp_import_compras_materials (
  id,
  code,
  level,
  name,
  unit,
  category,
  family,
  general_material_id,
  is_active,
  notes
) values
  ('ca_comercial_acero', 'ACERO', 'COMERCIAL', 'ACERO', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_acero_inoxidable', 'ACERO_INOXIDABLE', 'COMERCIAL', 'ACERO INOXIDABLE', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_aluminio', 'ALUMINIO', 'COMERCIAL', 'ALUMINIO', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_aluminio_perfil', 'ALUMINIO_PERFIL', 'COMERCIAL', 'ALUMINIO PERFIL', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_americano', 'AMERICANO', 'COMERCIAL', 'AMERICANO', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_arbol_de_levas', 'ARBOL_DE_LEVAS', 'COMERCIAL', 'ARBOL DE LEVAS', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_basura', 'BASURA', 'COMERCIAL', 'BASURA', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_bond', 'BOND', 'COMERCIAL', 'BOND', 'KG', 'PAPEL', 'PAPEL', 'ca_general_papel', true, null),
  ('ca_comercial_bote_aluminio', 'BOTE_ALUMINIO', 'COMERCIAL', 'BOTE ALUMINIO', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_bote_chilero', 'BOTE_CHILERO', 'COMERCIAL', 'BOTE CHILERO', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_botellas_pet', 'BOTELLAS_PET', 'COMERCIAL', 'BOTELLAS PET', 'KG', 'PLASTICO', 'PLASTICO', 'ca_general_plastico', true, null),
  ('ca_comercial_bronces_sucio', 'BRONCES_SUCIO', 'COMERCIAL', 'BRONCES SUCIO', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_cable_arnes_electrico', 'CABLE_ARNES_ELECTRICO', 'COMERCIAL', 'CABLE ARNES ELECTRICO', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_cajon_madera', 'CAJON_MADERA', 'COMERCIAL', 'CAJON MADERA', 'KG', 'MADERA', 'MADERA', 'ca_general_madera', true, null),
  ('ca_comercial_caple', 'CAPLE', 'COMERCIAL', 'CAPLE', 'KG', 'PAPEL', 'PAPEL', 'ca_general_papel', true, null),
  ('ca_comercial_caple_cajilla', 'CAPLE_CAJILLA', 'COMERCIAL', 'CAPLE CAJILLA', 'KG', 'PAPEL', 'PAPEL', 'ca_general_papel', true, null),
  ('ca_comercial_carton', 'CARTON', 'COMERCIAL', 'CARTON', 'KG', 'CARTON', 'CARTON', 'ca_general_carton', true, null),
  ('ca_comercial_carton_coresba', 'CARTON_CORESBA', 'COMERCIAL', 'CARTON CORESBA', 'KG', 'CARTON', 'CARTON', 'ca_general_carton', true, null),
  ('ca_comercial_carton_fortaleza', 'CARTON_FORTALEZA', 'COMERCIAL', 'CARTON FORTALEZA', 'KG', 'CARTON', 'CARTON', 'ca_general_carton', true, null),
  ('ca_comercial_carton_nacional', 'CARTON_NACIONAL', 'COMERCIAL', 'CARTON NACIONAL', 'KG', 'CARTON', 'CARTON', 'ca_general_carton', true, null),
  ('ca_comercial_carton_recogido', 'CARTON_RECOGIDO', 'COMERCIAL', 'CARTON RECOGIDO', 'KG', 'CARTON', 'CARTON', 'ca_general_carton', true, null),
  ('ca_comercial_carton_strokpack', 'CARTON_STROKPACK', 'COMERCIAL', 'CARTON STROKPACK', 'KG', 'CARTON', 'CARTON', 'ca_general_carton', true, null),
  ('ca_comercial_charola_pet', 'CHAROLA_PET', 'COMERCIAL', 'CHAROLA PET', 'KG', 'PLASTICO', 'PLASTICO', 'ca_general_plastico', true, null),
  ('ca_comercial_chatarra', 'CHATARRA', 'COMERCIAL', 'CHATARRA', 'KG', 'CHATARRA', 'CHATARRA', 'ca_general_chatarra', true, null),
  ('ca_comercial_chatarra_agroquimicos', 'CHATARRA_AGROQUIMICOS', 'COMERCIAL', 'CHATARRA AGROQUIMICOS', 'KG', 'CHATARRA', 'CHATARRA', 'ca_general_chatarra', true, null),
  ('ca_comercial_chatarra_carrocerias_halcon', 'CHATARRA_CARROCERIAS_HALCON', 'COMERCIAL', 'CHATARRA CARROCERIAS HALCON', 'KG', 'CHATARRA', 'CHATARRA', 'ca_general_chatarra', true, null),
  ('ca_comercial_chatarra_coresba', 'CHATARRA_CORESBA', 'COMERCIAL', 'CHATARRA CORESBA', 'KG', 'CHATARRA', 'CHATARRA', 'ca_general_chatarra', true, null),
  ('ca_comercial_chatarra_ferrebaztan', 'CHATARRA_FERREBAZTAN', 'COMERCIAL', 'CHATARRA FERREBAZTAN', 'KG', 'CHATARRA', 'CHATARRA', 'ca_general_chatarra', true, null),
  ('ca_comercial_chatarra_general', 'CHATARRA_GENERAL', 'COMERCIAL', 'CHATARRA GENERAL', 'KG', 'CHATARRA', 'CHATARRA', 'ca_general_chatarra', true, null),
  ('ca_comercial_chatarra_mixto', 'CHATARRA_MIXTO', 'COMERCIAL', 'CHATARRA MIXTO', 'KG', 'CHATARRA', 'CHATARRA', 'ca_general_chatarra', true, null),
  ('ca_comercial_chatarra_tresguerras', 'CHATARRA_TRESGUERRAS', 'COMERCIAL', 'CHATARRA TRESGUERRAS', 'KG', 'CHATARRA', 'CHATARRA', 'ca_general_chatarra', true, null),
  ('ca_comercial_chatarra_victor_garcia', 'CHATARRA_VICTOR_GARCIA', 'COMERCIAL', 'CHATARRA VICTOR GARCIA', 'KG', 'CHATARRA', 'CHATARRA', 'ca_general_chatarra', true, null),
  ('ca_comercial_cintas_sierra', 'CINTAS_SIERRA', 'COMERCIAL', 'CINTAS SIERRA', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_cobre', 'COBRE', 'COMERCIAL', 'COBRE', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_cobre_sucio', 'COBRE_SUCIO', 'COMERCIAL', 'COBRE SUCIO', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_compras', 'COMPRAS', 'COMERCIAL', 'COMPRAS', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_corrugado_carton', 'CORRUGADO_CARTON', 'COMERCIAL', 'CORRUGADO CARTON', 'KG', 'CARTON', 'CARTON', 'ca_general_carton', true, null),
  ('ca_comercial_cubetas_de_plastico', 'CUBETAS_DE_PLASTICO', 'COMERCIAL', 'CUBETAS DE PLASTICO', 'KG', 'PLASTICO', 'PLASTICO', 'ca_general_plastico', true, null),
  ('ca_comercial_destruccion', 'DESTRUCCION', 'COMERCIAL', 'DESTRUCCION', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_destruccion_fiscal', 'DESTRUCCION_FISCAL', 'COMERCIAL', 'DESTRUCCION FISCAL', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_electronicos', 'ELECTRONICOS', 'COMERCIAL', 'ELECTRONICOS', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_filtros_de_celulosa', 'FILTROS_DE_CELULOSA', 'COMERCIAL', 'FILTROS DE CELULOSA', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_flecha', 'FLECHA', 'COMERCIAL', 'FLECHA', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_flete', 'FLETE', 'COMERCIAL', 'FLETE', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_folleto', 'FOLLETO', 'COMERCIAL', 'FOLLETO', 'KG', 'PAPEL', 'PAPEL', 'ca_general_papel', true, null),
  ('ca_comercial_garrafa', 'GARRAFA', 'COMERCIAL', 'GARRAFA', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_lena', 'LENA', 'COMERCIAL', 'LENA', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_madera', 'MADERA', 'COMERCIAL', 'MADERA', 'KG', 'MADERA', 'MADERA', 'ca_general_madera', true, null),
  ('ca_comercial_madera_tarimas_120_x_100', 'MADERA_TARIMAS_120_X_100', 'COMERCIAL', 'MADERA TARIMAS 120 X 100', 'KG', 'MADERA', 'MADERA', 'ca_general_madera', true, null),
  ('ca_comercial_maquinaria_chatarra', 'MAQUINARIA_CHATARRA', 'COMERCIAL', 'MAQUINARIA CHATARRA', 'KG', 'CHATARRA', 'CHATARRA', 'ca_general_chatarra', true, null),
  ('ca_comercial_motores', 'MOTORES', 'COMERCIAL', 'MOTORES', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_paca_de_carton', 'PACA_DE_CARTON', 'COMERCIAL', 'PACA DE CARTON', 'KG', 'CARTON', 'CARTON', 'ca_general_carton', true, null),
  ('ca_comercial_pacas_de_carton', 'PACAS_DE_CARTON', 'COMERCIAL', 'PACAS DE CARTON', 'KG', 'CARTON', 'CARTON', 'ca_general_carton', true, null),
  ('ca_comercial_papel', 'PAPEL', 'COMERCIAL', 'PAPEL', 'KG', 'PAPEL', 'PAPEL', 'ca_general_papel', true, null),
  ('ca_comercial_pedaceria_madera', 'PEDACERIA_MADERA', 'COMERCIAL', 'PEDACERIA MADERA', 'KG', 'MADERA', 'MADERA', 'ca_general_madera', true, null),
  ('ca_comercial_piston_de_acero', 'PISTON_DE_ACERO', 'COMERCIAL', 'PISTON DE ACERO', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_placa', 'PLACA', 'COMERCIAL', 'PLACA', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_placa_corta', 'PLACA_CORTA', 'COMERCIAL', 'PLACA CORTA', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_placa_larga', 'PLACA_LARGA', 'COMERCIAL', 'PLACA LARGA', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_placa_y_estructura', 'PLACA_Y_ESTRUCTURA', 'COMERCIAL', 'PLACA Y ESTRUCTURA', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_plastico', 'PLASTICO', 'COMERCIAL', 'PLASTICO', 'KG', 'PLASTICO', 'PLASTICO', 'ca_general_plastico', true, null),
  ('ca_comercial_plastico_lavado', 'PLASTICO_LAVADO', 'COMERCIAL', 'PLASTICO LAVADO', 'KG', 'PLASTICO', 'PLASTICO', 'ca_general_plastico', true, null),
  ('ca_comercial_plastico_mixto', 'PLASTICO_MIXTO', 'COMERCIAL', 'PLASTICO MIXTO', 'KG', 'PLASTICO', 'PLASTICO', 'ca_general_plastico', true, null),
  ('ca_comercial_plolietileno', 'PLOLIETILENO', 'COMERCIAL', 'PLOLIETILENO', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_poliestireno_rigido_plastico_rigido', 'POLIESTIRENO_RIGIDO_PLASTICO_RIGIDO', 'COMERCIAL', 'POLIESTIRENO RIGIDO PLASTICO RIGIDO', 'KG', 'PLASTICO', 'PLASTICO', 'ca_general_plastico', true, null),
  ('ca_comercial_polietileno', 'POLIETILENO', 'COMERCIAL', 'POLIETILENO', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_polietileno_de_baja_densidad_polifoam', 'POLIETILENO_DE_BAJA_DENSIDAD_POLIFOAM', 'COMERCIAL', 'POLIETILENO DE BAJA DENSIDAD POLIFOAM', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_porron_plastico_200l', 'PORRON_PLASTICO_200L', 'COMERCIAL', 'PORRON PLASTICO 200L', 'KG', 'PLASTICO', 'PLASTICO', 'ca_general_plastico', true, null),
  ('ca_comercial_rebaba', 'REBABA', 'COMERCIAL', 'REBABA', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_residuos_electricos', 'RESIDUOS_ELECTRICOS', 'COMERCIAL', 'RESIDUOS ELECTRICOS', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_residuos_electronicos', 'RESIDUOS_ELECTRONICOS', 'COMERCIAL', 'RESIDUOS ELECTRONICOS', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_sabados_viaje', 'SABADOS_VIAJE', 'COMERCIAL', 'SABADOS(VIAJE)', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_tambos_de_carton', 'TAMBOS_DE_CARTON', 'COMERCIAL', 'TAMBOS DE CARTON', 'KG', 'CARTON', 'CARTON', 'ca_general_carton', true, null),
  ('ca_comercial_tambos_de_metal', 'TAMBOS_DE_METAL', 'COMERCIAL', 'TAMBOS DE METAL', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_tambos_metalicos', 'TAMBOS_METALICOS', 'COMERCIAL', 'TAMBOS METALICOS', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_tambos_plastico', 'TAMBOS_PLASTICO', 'COMERCIAL', 'TAMBOS PLASTICO', 'KG', 'PLASTICO', 'PLASTICO', 'ca_general_plastico', true, null),
  ('ca_comercial_tarima', 'TARIMA', 'COMERCIAL', 'TARIMA', 'KG', 'MADERA', 'MADERA', 'ca_general_madera', true, null),
  ('ca_comercial_tarima_madera', 'TARIMA_MADERA', 'COMERCIAL', 'TARIMA MADERA', 'KG', 'MADERA', 'MADERA', 'ca_general_madera', true, null),
  ('ca_comercial_tarimas', 'TARIMAS', 'COMERCIAL', 'TARIMAS', 'KG', 'MADERA', 'MADERA', 'ca_general_madera', true, null),
  ('ca_comercial_textil', 'TEXTIL', 'COMERCIAL', 'TEXTIL', 'KG', 'TEXTIL', 'TEXTIL', 'ca_general_textil', true, null),
  ('ca_comercial_unicel', 'UNICEL', 'COMERCIAL', 'UNICEL', 'KG', 'OTROS', 'OTROS', 'ca_general_otros', true, null),
  ('ca_comercial_vidrio', 'VIDRIO', 'COMERCIAL', 'VIDRIO', 'KG', 'VIDRIO', 'VIDRIO', 'ca_general_vidrio', true, null),
  ('ca_general_carton', 'CARTON', 'GENERAL', 'CARTON', 'KG', 'CARTON', null, null, true, 'GENERAL BASE MAYOREO'),
  ('ca_general_chatarra', 'CHATARRA', 'GENERAL', 'CHATARRA', 'KG', 'CHATARRA', null, null, true, 'GENERAL BASE MAYOREO'),
  ('ca_general_madera', 'MADERA', 'GENERAL', 'MADERA', 'KG', 'MADERA', null, null, true, 'GENERAL BASE MAYOREO'),
  ('ca_general_metal', 'METAL', 'GENERAL', 'METAL', 'KG', 'METAL', null, null, true, 'GENERAL BASE MAYOREO'),
  ('ca_general_otros', 'OTROS', 'GENERAL', 'OTROS', 'KG', 'OTROS', null, null, true, 'GENERAL BASE MAYOREO'),
  ('ca_general_papel', 'PAPEL', 'GENERAL', 'PAPEL', 'KG', 'PAPEL', null, null, true, 'GENERAL BASE MAYOREO'),
  ('ca_general_plastico', 'PLASTICO', 'GENERAL', 'PLASTICO', 'KG', 'PLASTICO', null, null, true, 'GENERAL BASE MAYOREO'),
  ('ca_general_textil', 'TEXTIL', 'GENERAL', 'TEXTIL', 'KG', 'TEXTIL', null, null, true, 'GENERAL BASE MAYOREO'),
  ('ca_general_vidrio', 'VIDRIO', 'GENERAL', 'VIDRIO', 'KG', 'VIDRIO', null, null, true, 'GENERAL BASE MAYOREO');

insert into public.compras_material_catalog (
  id,
  code,
  level,
  name,
  unit,
  category,
  family,
  general_material_id,
  is_active,
  notes
)
select
  src.id,
  src.code,
  src.level,
  src.name,
  src.unit,
  src.category,
  src.family,
  null,
  src.is_active,
  src.notes
from tmp_import_compras_materials src
where src.level = 'GENERAL'
  and not exists (
    select 1
    from public.compras_material_catalog dst
    where upper(dst.name) = upper(src.name)
      and dst.level = src.level
  );

update public.compras_material_catalog dst
set
  code = src.code,
  unit = src.unit,
  category = src.category,
  family = src.family,
  is_active = src.is_active,
  notes = src.notes
from tmp_import_compras_materials src
where src.level = 'GENERAL'
  and upper(dst.name) = upper(src.name)
  and dst.level = src.level;

insert into public.compras_material_catalog (
  id,
  code,
  level,
  name,
  unit,
  category,
  family,
  general_material_id,
  is_active,
  notes
)
select
  src.id,
  src.code,
  src.level,
  src.name,
  src.unit,
  src.category,
  src.family,
  general_dst.id,
  src.is_active,
  src.notes
from tmp_import_compras_materials src
join tmp_import_compras_materials general_src
  on general_src.id = src.general_material_id
join public.compras_material_catalog general_dst
  on upper(general_dst.name) = upper(general_src.name)
 and general_dst.level = 'GENERAL'
where src.level = 'COMERCIAL'
  and not exists (
    select 1
    from public.compras_material_catalog dst
    where upper(dst.name) = upper(src.name)
      and dst.level = src.level
  );

update public.compras_material_catalog dst
set
  code = src.code,
  unit = src.unit,
  category = src.category,
  family = src.family,
  general_material_id = general_dst.id,
  is_active = src.is_active,
  notes = src.notes
from tmp_import_compras_materials src
join tmp_import_compras_materials general_src
  on general_src.id = src.general_material_id
join public.compras_material_catalog general_dst
  on upper(general_dst.name) = upper(general_src.name)
 and general_dst.level = 'GENERAL'
where src.level = 'COMERCIAL'
  and upper(dst.name) = upper(src.name)
  and dst.level = src.level;

create temporary table tmp_import_compras_prices (
  id text,
  company_name text,
  material_name text,
  material_level text,
  final_price numeric(14,4),
  is_active boolean,
  notes text
) on commit drop;

insert into tmp_import_compras_prices (
  id,
  company_name,
  material_name,
  material_level,
  final_price,
  is_active,
  notes
) values
  ('cpr_acroma_carton', 'ACROMA', 'CARTON', 'COMERCIAL', 1.0000, true, null),
  ('cpr_acroma_chatarra', 'ACROMA', 'CHATARRA', 'COMERCIAL', 3.0000, true, null),
  ('cpr_acroma_garrafa', 'ACROMA', 'GARRAFA', 'COMERCIAL', 7.0000, true, null),
  ('cpr_acroma_plastico', 'ACROMA', 'PLASTICO', 'COMERCIAL', 1.2000, true, null),
  ('cpr_acroma_porron_plastico_200l', 'ACROMA', 'PORRON PLASTICO 200L', 'COMERCIAL', 17.0000, true, null),
  ('cpr_acroma_tambos_de_metal', 'ACROMA', 'TAMBOS DE METAL', 'COMERCIAL', 33.0000, true, null),
  ('cpr_adolfo_gutierrez_plastico', 'ADOLFO GUTIERREZ', 'PLASTICO', 'COMERCIAL', 0.5000, true, null),
  ('cpr_avon_acero_inoxidable', 'AVON', 'ACERO INOXIDABLE', 'COMERCIAL', 8.5000, true, null),
  ('cpr_avon_aluminio', 'AVON', 'ALUMINIO', 'COMERCIAL', 20.0000, true, null),
  ('cpr_avon_bond', 'AVON', 'BOND', 'COMERCIAL', 1.2000, true, null),
  ('cpr_avon_caple_cajilla', 'AVON', 'CAPLE CAJILLA', 'COMERCIAL', 0.7000, true, null),
  ('cpr_avon_chatarra', 'AVON', 'CHATARRA', 'COMERCIAL', 2.8000, true, null),
  ('cpr_avon_corrugado_carton', 'AVON', 'CORRUGADO CARTON', 'COMERCIAL', 1.2000, true, null),
  ('cpr_avon_filtros_de_celulosa', 'AVON', 'FILTROS DE CELULOSA', 'COMERCIAL', 0.5000, true, null),
  ('cpr_avon_folleto', 'AVON', 'FOLLETO', 'COMERCIAL', 0.7000, true, null),
  ('cpr_avon_pedaceria_madera', 'AVON', 'PEDACERIA MADERA', 'COMERCIAL', 0.0000, true, null),
  ('cpr_avon_plastico_lavado', 'AVON', 'PLASTICO LAVADO', 'COMERCIAL', 0.1000, true, null),
  ('cpr_avon_plastico_mixto', 'AVON', 'PLASTICO MIXTO', 'COMERCIAL', 1.2000, true, null),
  ('cpr_avon_sabados_viaje', 'AVON', 'SABADOS(VIAJE)', 'COMERCIAL', 500.0000, true, null),
  ('cpr_avon_tarima_madera', 'AVON', 'TARIMA MADERA', 'COMERCIAL', 1.0000, true, null),
  ('cpr_avon_textil', 'AVON', 'TEXTIL', 'COMERCIAL', 1.8000, true, null),
  ('cpr_avon_vidrio', 'AVON', 'VIDRIO', 'COMERCIAL', 0.1000, true, null),
  ('cpr_cedis_cajon_madera', 'CEDIS', 'CAJON MADERA', 'COMERCIAL', 12.0000, true, null),
  ('cpr_cedis_carton', 'CEDIS', 'CARTON', 'COMERCIAL', 1.4000, true, null),
  ('cpr_cedis_chatarra', 'CEDIS', 'CHATARRA', 'COMERCIAL', 3.0600, true, null),
  ('cpr_cedis_lena', 'CEDIS', 'LENA', 'COMERCIAL', 0.3500, true, null),
  ('cpr_cedis_plastico', 'CEDIS', 'PLASTICO', 'COMERCIAL', 2.2500, true, null),
  ('cpr_decasa_carton', 'DECASA', 'CARTON', 'COMERCIAL', 1.1000, true, '15/10/24'),
  ('cpr_dimeca_carton', 'DIMECA', 'CARTON', 'COMERCIAL', 1.4000, true, '26/07/24'),
  ('cpr_emilio_sandoval_carton', 'EMILIO SANDOVAL', 'CARTON', 'COMERCIAL', 2.0000, true, 'BAJA 0.20 28/05/2025'),
  ('cpr_emilio_sandoval_chatarra_mixto', 'EMILIO SANDOVAL', 'CHATARRA MIXTO', 'COMERCIAL', 4.0000, true, 'sube 0.20 centavos 20/junio/2025 BAJA 0.60 CENTAVOS 03/07/2025  ajuste de precio Jp 31/07/2025'),
  ('cpr_emilio_sandoval_placa', 'EMILIO SANDOVAL', 'PLACA', 'COMERCIAL', 3.3000, true, 'sube 0.20 centavos 20/junio/2025 BAJA 0.60 CENTAVOS 03/07/2025'),
  ('cpr_facturas_compras', 'FACTURAS', 'COMPRAS', 'COMERCIAL', 1.0000, true, '12/01/23 0:00'),
  ('cpr_fernando_rubio_aluminio_perfil', 'FERNANDO RUBIO', 'ALUMINIO PERFIL', 'COMERCIAL', 27.0000, true, '19/09/24'),
  ('cpr_fernando_rubio_chatarra', 'FERNANDO RUBIO', 'CHATARRA', 'COMERCIAL', 2.5000, true, 'MAPUPITA ALZA   sube 0.20 centavos 20/junio/2025 BAJA 0.60 CENTAVOS 03/07/2025'),
  ('cpr_fernando_rubio_chatarra_agroquimicos', 'FERNANDO RUBIO', 'CHATARRA AGROQUIMICOS', 'COMERCIAL', 2.5000, true, 'sube 0.20 centavos 20/junio/2025 BAJA 0.60 CENTAVOS 03/07/2025'),
  ('cpr_gescrap_carton', 'GESCRAP', 'CARTON', 'COMERCIAL', 1.1000, true, null),
  ('cpr_gkn_forja_basura', 'GKN FORJA', 'BASURA', 'COMERCIAL', 0.4500, true, '24/04/24'),
  ('cpr_gkn_forja_flete', 'GKN FORJA', 'FLETE', 'COMERCIAL', 3300.0000, true, '24/04/24'),
  ('cpr_gkn_maquinados_basura', 'GKN MAQUINADOS', 'BASURA', 'COMERCIAL', 0.4500, true, '24/04/24'),
  ('cpr_gkn_maquinados_flete', 'GKN MAQUINADOS', 'FLETE', 'COMERCIAL', 3300.0000, true, '24/04/24'),
  ('cpr_gkn_villagran_basura', 'GKN VILLAGRAN', 'BASURA', 'COMERCIAL', 0.4500, true, '24/04/24'),
  ('cpr_gkn_villagran_flete', 'GKN VILLAGRAN', 'FLETE', 'COMERCIAL', 3300.0000, true, '24/04/24'),
  ('cpr_grupo_rescrain_carton', 'GRUPO RESCRAIN', 'CARTON', 'COMERCIAL', 1.3000, true, null),
  ('cpr_hanwa_basura', 'HANWA', 'BASURA', 'COMERCIAL', 0.0000, true, null),
  ('cpr_hanwa_carton', 'HANWA', 'CARTON', 'COMERCIAL', 1.2000, true, null),
  ('cpr_hanwa_chatarra', 'HANWA', 'CHATARRA', 'COMERCIAL', 4.1500, true, '10-07-20255'),
  ('cpr_hanwa_lena', 'HANWA', 'LENA', 'COMERCIAL', 0.3500, true, null),
  ('cpr_hanwa_plastico', 'HANWA', 'PLASTICO', 'COMERCIAL', 2.0000, true, null),
  ('cpr_hanwa_residuos_electricos', 'HANWA', 'RESIDUOS ELECTRICOS', 'COMERCIAL', 3.5000, true, null),
  ('cpr_jose_luis_muniz_chatarra', 'JOSE LUIS MUNIZ', 'CHATARRA', 'COMERCIAL', 3.9000, true, '14/10/24'),
  ('cpr_juan_solis_aluminio', 'JUAN SOLIS', 'ALUMINIO', 'COMERCIAL', 23.0000, true, '23/04/24'),
  ('cpr_juan_solis_chatarra', 'JUAN SOLIS', 'CHATARRA', 'COMERCIAL', 3.9000, true, '23/04/204'),
  ('cpr_juan_solis_rebaba', 'JUAN SOLIS', 'REBABA', 'COMERCIAL', 3.3000, true, '01-mar-24'),
  ('cpr_ks_aluminio', 'KS', 'ALUMINIO', 'COMERCIAL', 15.0000, true, null),
  ('cpr_ks_basura', 'KS', 'BASURA', 'COMERCIAL', 0.0000, true, null),
  ('cpr_ks_carton', 'KS', 'CARTON', 'COMERCIAL', 1.0000, true, '27/09/24'),
  ('cpr_ks_chatarra_general', 'KS', 'CHATARRA GENERAL', 'COMERCIAL', 3.3400, true, null),
  ('cpr_ks_cintas_sierra', 'KS', 'CINTAS SIERRA', 'COMERCIAL', 132.0000, true, null),
  ('cpr_ks_cobre', 'KS', 'COBRE', 'COMERCIAL', 36.0000, true, null),
  ('cpr_ks_madera', 'KS', 'MADERA', 'COMERCIAL', 0.3000, true, '27/09/24'),
  ('cpr_ks_piston_de_acero', 'KS', 'PISTON DE ACERO', 'COMERCIAL', 3.1100, true, null),
  ('cpr_ks_plastico', 'KS', 'PLASTICO', 'COMERCIAL', 2.6400, true, null),
  ('cpr_ks_rebaba', 'KS', 'REBABA', 'COMERCIAL', 3.1100, true, null),
  ('cpr_licbox_carton', 'LICBOX', 'CARTON', 'COMERCIAL', 1.4000, true, 'BAJA 0.30 CENTAVOS CARTON 13/02/2025              BAJA 0.30 CENTAVOS 14/10/2025 BAJA 0.10 CENTAVOS 13/11/2025      baja 0.20 12/12/2025  baja 0.20 22/12/2025, BAJA .10 CENTAVOS 02/03/2026, SUBE 0.10 CENTAVOS 12/03/2026, SUBE 0.10 CENTAVOS 19/03/2026, BAJA 0.20 CENTAVOS 27/04/2026'),
  ('cpr_licbox_paca_de_carton', 'LICBOX', 'PACA DE CARTON', 'COMERCIAL', 2.7000, true, '20/08/24'),
  ('cpr_lourdes_coronilla_carton', 'LOURDES CORONILLA', 'CARTON', 'COMERCIAL', 2.4000, true, '05/06/25'),
  ('cpr_martin_guzman_chatarra', 'MARTIN GUZMAN', 'CHATARRA', 'COMERCIAL', 5.1500, true, 'AJUSTE 19/11/2025 AJUSTE PRECIO 5.10, SUBE 0.20 CENTAVOS 07/01/2025 sube 0.25 centavos en deacero 13/01/2026, SUBE 19/01/2026 0.10 CENTAVOS, , SUBE 27/01/2026 0.10 CENTAVOS, SUBE 03/02/2026 0.20 CENTAVOS,  AJUSTE .35 AUT LUIS 18/02/2026, SUBE 25/02/2026 0.10 CENTAVOS, SUBE 27/02/2026 0.10 CENTAVOS, BAJA .40 CENTAVOS 10/03/2026, BAJA .40 CENTAVOS 18/03/2026, BAJA .15 CENTAVOS 24/03/2026, (CANCELACION DE BAJA) SUBE .40 CENTAVOS 30/03/2026,  BAJA .40 CENTAVOS 06/04/2026, BAJA .40 CENTAVOS 27/04/2026'),
  ('cpr_martin_guzman_flecha', 'MARTIN GUZMAN', 'FLECHA', 'COMERCIAL', 5.3500, true, 'AJUSTE 06/06/2025,sube 0.20 centavos 20/junio/2025 BAJA 0.60 CENTAVOS 03/07/2025 AJUSTE PRECIOS 10-09-2025 AJUSTE 1/10/25AJUSTE 19/11/2025 AJUSTE PRECIO 5.25, SUBE 0.20 CENTAVOS 07/01/2025 sube 0.25 centavos en deacero 13/01/2026, SUBE 19/01/2026 0.10 CENTAVOS, SUBE 28/01/2026 0.10 CENTAVOS, SUBE 03/02/2026 0.20 CENTAVOS, AJUSTE .40 AUT LUIS 18/02/2026, SUBE 25/02/2026 0.10 CENTAVOS, SUBE 27/02/2026 0.10 CENTAVOS, BAJA .40 CENTAVOS 10/03/2026, BAJA .40 CENTAVOS 18/03/2026, BAJA .15 CENTAVOS 24/03/2026, (CANCELACION DE BAJA) SUBE .40 CENTAVOS 30/03/2026,  BAJA .40 CENTAVOS 06/04/2026, BAJA .40 CENTAVOS 27/04/2026'),
  ('cpr_martin_guzman_placa_corta', 'MARTIN GUZMAN', 'PLACA CORTA', 'COMERCIAL', 5.4000, true, 'AJUSTE 06/06/2025,sube 0.20 centavos 20/junio/2025 BAJA 0.60 CENTAVOS 03/07/2025 AJUSTE PRECIOS 10-09-2025 AJUSTE 1/10/25 AJUSTE PRECIO 5.40, SUBE 0.20 CENTAVOS 07/01/2025 sube 0.25 centavos en deacero 13/01/2026, SUBE 19/01/2026 0.10 CENTAVOS, SUBE 28/01/2026 0.10 CENTAVOS, SUBE 03/02/2026 0.20 CENTAVOS,  AJUSTE .30 AUT LUIS 18/02/2026, SUBE 25/02/2026 0.10 CENTAVOS, SUBE 27/02/2026 0.10 CENTAVOS, BAJA .40 CENTAVOS 10/03/2026, BAJA .40 CENTAVOS 18/03/2026, BAJA .15 CENTAVOS 24/03/2026, (CANCELACION DE BAJA) SUBE .40 CENTAVOS 30/03/2026,  BAJA .40 CENTAVOS 06/04/2026, BAJA .40 CENTAVOS 27/04/2026'),
  ('cpr_martin_guzman_placa_larga', 'MARTIN GUZMAN', 'PLACA LARGA', 'COMERCIAL', 5.1500, true, 'AJUSTE PRECIO 5.10, SUBE 0.20 CENTAVOS 07/01/2025 sube 0.25 centavos en deacero 13/01/2026, SUBE 19/01/2026 0.10 CENTAVOS, , SUBE 27/01/2026 0.10 CENTAVOS, SUBE 03/02/2026 0.20 CENTAVOS,  AJUSTE .35 AUT LUIS 18/02/2026, SUBE 25/02/2026 0.10 CENTAVOS, SUBE 27/02/2026 0.10 CENTAVOS, BAJA .40 CENTAVOS 10/03/2026, BAJA .40 CENTAVOS 18/03/2026, BAJA .15 CENTAVOS 24/03/2026, (CANCELACION DE BAJA) SUBE .40 CENTAVOS 30/03/2026,  BAJA .40 CENTAVOS 06/04/2026, BAJA .40 CENTAVOS 27/04/2026'),
  ('cpr_martin_guzman_rebaba', 'MARTIN GUZMAN', 'REBABA', 'COMERCIAL', 4.1000, true, 'AJUSTE 06/06/2025 BAJA 0.60 CENTAVOS 03/07/2025 AJUSTE PRECIO 4.10, SUBE 0.20 CENTAVOS 07/01/2025 sube 0.25 centavos en deacero 13/01/2026, SUBE 19/01/2026 0.10 CENTAVOS, SUBE 28/01/2026 0.10 CENTAVOS, SUBE 03/02/2026 0.20 CENTAVOS,  AJUSTE .40 AUT LUIS 18/02/2026, SUBE 25/02/2026 0.10 CENTAVOS, SUBE 27/02/2026 0.10 CENTAVOS, BAJA .40 CENTAVOS 10/03/2026, BAJA .40 CENTAVOS 18/03/2026, BAJA .15 CENTAVOS 24/03/2026, (CANCELACION DE BAJA) SUBE .40 CENTAVOS 30/03/2026,  BAJA .40 CENTAVOS 06/04/2026, BAJA .40 CENTAVOS 27/04/2026'),
  ('cpr_mauricio_alcala_aluminio', 'MAURICIO ALCALA', 'ALUMINIO', 'COMERCIAL', 15.7500, true, null),
  ('cpr_mauricio_alcala_chatarra', 'MAURICIO ALCALA', 'CHATARRA', 'COMERCIAL', 4.8000, true, null),
  ('cpr_mauricio_garcia_chatarra', 'MAURICIO GARCIA', 'CHATARRA', 'COMERCIAL', 4.4000, true, null),
  ('cpr_migavid_carton', 'MIGAVID', 'CARTON', 'COMERCIAL', 2.3000, true, '01/08/24'),
  ('cpr_migavid_chatarra', 'MIGAVID', 'CHATARRA', 'COMERCIAL', 3.8500, true, '23-10-2025 SUBE 0.20 07/01/2026, SUBE 0.25 13/01/2026, SUBE 0.10 19/01/2026, BAJA .40 CENTAVOS 10/03/2026, BAJA .40 CENTAVOS 18/03/2026,  BAJA .15 CENTAVOS 24/03/2026, (CANCELACION DE BAJA) SUBE .40 CENTAVOS 30/03/2026,  BAJA .40 CENTAVOS 06/04/2026, BAJA .40 CENTAVOS 27/04/2026, SUBE 0.20 CENTAVOS 06/05/2026'),
  ('cpr_migavid_rebaba', 'MIGAVID', 'REBABA', 'COMERCIAL', 2.7500, true, '23-10-2025, SUBE 0.20 07/01/2026, SUBE 0.25 13/01/2026, SUBE 0.10 19/01/2026, BAJA .40 CENTAVOS 10/03/2026, BAJA .40 CENTAVOS 18/03/2026,  BAJA .15 CENTAVOS 24/03/2026, (CANCELACION DE BAJA) SUBE .40 CENTAVOS 30/03/2026,  BAJA .40 CENTAVOS 06/04/2026, BAJA .40 CENTAVOS 27/04/2026, SUBE 0.20 CENTAVOS 06/05/2026'),
  ('cpr_migue_apaseo_chatarra', 'MIGUE APASEO', 'CHATARRA', 'COMERCIAL', 2.5000, true, 'chatarra recuperada'),
  ('cpr_miguel_ayala_chatarra', 'MIGUEL AYALA', 'CHATARRA', 'COMERCIAL', 4.9000, true, '19/09/24'),
  ('cpr_miguel_sanchez_americano', 'MIGUEL SANCHEZ', 'AMERICANO', 'COMERCIAL', 3.2000, true, null),
  ('cpr_miguel_sanchez_carton_nacional', 'MIGUEL SANCHEZ', 'CARTON NACIONAL', 'COMERCIAL', 2.4000, true, '13/05/25'),
  ('cpr_miguel_sanchez_pacas_de_carton', 'MIGUEL SANCHEZ', 'PACAS DE CARTON', 'COMERCIAL', 3.2000, true, null),
  ('cpr_monroe_basura', 'MONROE', 'BASURA', 'COMERCIAL', 0.0000, true, null),
  ('cpr_monroe_bote_aluminio', 'MONROE', 'BOTE ALUMINIO', 'COMERCIAL', 15.0000, true, null),
  ('cpr_monroe_cajon_madera', 'MONROE', 'CAJON MADERA', 'COMERCIAL', 12.0000, true, null),
  ('cpr_monroe_carton', 'MONROE', 'CARTON', 'COMERCIAL', 1.4000, true, null),
  ('cpr_monroe_cobre', 'MONROE', 'COBRE', 'COMERCIAL', 25.0000, true, null),
  ('cpr_monroe_destruccion', 'MONROE', 'DESTRUCCION', 'COMERCIAL', 4.5500, true, '04/03/25'),
  ('cpr_monroe_lena', 'MONROE', 'LENA', 'COMERCIAL', 0.3500, true, null),
  ('cpr_monroe_plastico', 'MONROE', 'PLASTICO', 'COMERCIAL', 2.2500, true, null),
  ('cpr_monroe_rebaba', 'MONROE', 'REBABA', 'COMERCIAL', 2.2700, true, null),
  ('cpr_monroe_tarimas', 'MONROE', 'TARIMAS', 'COMERCIAL', 13.0000, true, null),
  ('cpr_pirineos_acero_inoxidable', 'PIRINEOS', 'ACERO INOXIDABLE', 'COMERCIAL', 10.0000, true, '12/07/23 0:00'),
  ('cpr_pirineos_aluminio', 'PIRINEOS', 'ALUMINIO', 'COMERCIAL', 20.5000, true, '12/07/23 0:00'),
  ('cpr_pirineos_chatarra', 'PIRINEOS', 'CHATARRA', 'COMERCIAL', 5.8000, true, '12/07/23 0:00'),
  ('cpr_pirineos_motores', 'PIRINEOS', 'MOTORES', 'COMERCIAL', 11.5000, true, '12/07/23 0:00'),
  ('cpr_recicla_metal_carton', 'RECICLA METAL', 'CARTON', 'COMERCIAL', 1.6000, true, 'baja 01-08-2025 BAJA 0.20 CENTAVOS 14/10/2025BAJA 0.10 CENTAVOS 13/11/2025 baja 0.20 12/12/2025  baja 0.20 22/12/2025, BAJA .10 CENTAVOS 02/03/2026, SUBE 0.10 CENTAVOS 12/03/2026, SUBE 0.10 CENTAVOS 12/03/2026'),
  ('cpr_recicla_metal_carton_recogido', 'RECICLA METAL', 'CARTON RECOGIDO', 'COMERCIAL', 1.4000, true, 'baja 01-08-2025 BAJA 0.20 CENTAVOS 14/10/2025BAJA 0.10 CENTAVOS 13/11/2025 baja 0.20 12/12/2025 baja 0.20 22/12/2025, BAJA .10 CENTAVOS 02/03/2026, SUBE 0.10 CENTAVOS 12/03/2026, SUBE 0.10 CENTAVOS 12/03/2026'),
  ('cpr_ricardo_garcia_mendieta_americano', 'RICARDO GARCIA MENDIETA', 'AMERICANO', 'COMERCIAL', 4.2000, true, '20/11/24'),
  ('cpr_ricardo_garcia_mendieta_caple', 'RICARDO GARCIA MENDIETA', 'CAPLE', 'COMERCIAL', 1.7000, true, null),
  ('cpr_ricardo_garcia_mendieta_carton', 'RICARDO GARCIA MENDIETA', 'CARTON', 'COMERCIAL', 3.0000, true, null),
  ('cpr_ricardo_garcia_mendieta_flete', 'RICARDO GARCIA MENDIETA', 'FLETE', 'COMERCIAL', 1.0000, true, '11/27/2023 00:00:00'),
  ('cpr_rocio_carvajal_carton', 'ROCIO CARVAJAL', 'CARTON', 'COMERCIAL', 1.5000, true, 'BAJA 0.10 CENTAVOS 13/11/2025 BAJA 0.20 CENTAVOS 22/12/2025 SUBE 0.10 CENTAVOS 20/01/2026, BAJA .30 CENTAVOS 16/02/2026, AJUSTE .20 19/02/2026 AUT LUIS, BAJA .10 CENTAVOS 02/03/2026, SUBE 0.10 CENTAVOS 12/03/2026,  SUBE 0.10 CENTAVOS 19/03/2026'),
  ('cpr_rocio_carvajal_chatarra', 'ROCIO CARVAJAL', 'CHATARRA', 'COMERCIAL', 5.3000, true, null),
  ('cpr_rodolfo_vera_bote_chilero', 'RODOLFO VERA', 'BOTE CHILERO', 'COMERCIAL', 2.6000, true, 'Se informa que el día de mañana 3 de abril tenemos una Baja de 20 centavos en Deacero Celaya en las segundas y 30 centavos en las primeras'),
  ('cpr_rodolfo_vera_carton', 'RODOLFO VERA', 'CARTON', 'COMERCIAL', 1.5000, true, 'BAJA 0.10 CENTAVOS 08/12/2025 baja 0.20 12/12/2025 baja 0.20 22/12/2025 SUBE 0.10 CENTAVOS 20/01/2026, BAJA .20 CENTAVOS 03/01/2026, BAJA .10 CENTAVOS 10/02/2026, BAJA .30 CENTAVOS 16/02/2026, SUBE 0.20 CENTAVOS 19/02/2026, BAJA .10 CENTAVOS 02/03/2026,  SUBE 0.10 CENTAVOS 12/03/2026, SUBE 0.10 CENTAVOS 19/03/2026'),
  ('cpr_rodolfo_vera_carton_recogido', 'RODOLFO VERA', 'CARTON RECOGIDO', 'COMERCIAL', 1.4000, true, 'BAJA 0.10 CENTAVOS 08/12/2025 baja 0.20 12/12/2025 baja 0.20 22/12/2025 AJUSTE PRECIO LUISITO 29/12/2025 SUBE 0.10 CENTAVOS 20/01/2026,  BAJA .20 CENTAVOS 03/01/2026, BAJA .10 CENTAVOS 10/02/2026, BAJA .30 CENTAVOS 16/02/2026, SUBE 0.20 CENTAVOS 19/02/2026, BAJA .10 CENTAVOS 02/03/2026,  SUBE 0.10 CENTAVOS 12/03/2026, SUBE 0.10 CENTAVOS 19/03/2026'),
  ('cpr_rodolfo_vera_chatarra', 'RODOLFO VERA', 'CHATARRA', 'COMERCIAL', 5.3000, true, 'sube 07/01/2026 0.20 centavos sube 0.25 centavos en deacero 13/01/2026- ajuste precio a $5.40 (luis) SUBE 19/01/2026 0.10 CENTAVOS, SUBE 28/01/2026 0.10 CENTAVOS, SUBE 03/02/2026 0.20 CENTAVOS, SUBE 17/02/2026 0.20 CENTAVOS, SUBE 18/02/2026 0.10 CENTAVOS, SUBE 27/02/2026 0.10 CENTAVOS, BAJA .40 CENTAVOS 10/03/2026, BAJA .40 CENTAVOS 18/03/2026, BAJA .15 CENTAVOS 24/03/2026, AJUSTE .40 CENTAVOS 30/03/2026, BAJA .40 CENTAVOS 06/04/2026, BAJA .40 CENTAVOS 27/04/2026, SUBE 06/05/2026 0.20 CENTAVOS, SUBE 19/05/2026 0.20 CENTAVOS'),
  ('cpr_rodolfo_vera_rebaba', 'RODOLFO VERA', 'REBABA', 'COMERCIAL', 1.7000, true, 'Se informa que el día de mañana 3 de abril tenemos una Baja de 20 centavos en Deacero Celaya en las segundas y 30 centavos en las primeras'),
  ('cpr_ryobi_chatarra', 'RYOBI', 'CHATARRA', 'COMERCIAL', 4.8000, true, '05/09/24'),
  ('cpr_sanoh_carton', 'SANOH', 'CARTON', 'COMERCIAL', 0.0000, true, null),
  ('cpr_sanoh_chatarra', 'SANOH', 'CHATARRA', 'COMERCIAL', 4.0000, true, null),
  ('cpr_setexmes_basura', 'SETEXMES', 'BASURA', 'COMERCIAL', 0.0000, true, null),
  ('cpr_setexmes_carton', 'SETEXMES', 'CARTON', 'COMERCIAL', 0.9000, true, null),
  ('cpr_setexmes_chatarra', 'SETEXMES', 'CHATARRA', 'COMERCIAL', 2.3000, true, null),
  ('cpr_setexmes_lena', 'SETEXMES', 'LENA', 'COMERCIAL', 0.2000, true, null),
  ('cpr_setexmes_plastico', 'SETEXMES', 'PLASTICO', 'COMERCIAL', 1.5000, true, null),
  ('cpr_setexmes_tarima', 'SETEXMES', 'TARIMA', 'COMERCIAL', 5.0000, true, null),
  ('cpr_sierra_servicios_de_perforacion_destruccion_fiscal', 'SIERRA SERVICIOS DE PERFORACION', 'DESTRUCCION FISCAL', 'COMERCIAL', 2.8000, true, null),
  ('cpr_tenneco_chatarra', 'TENNECO', 'CHATARRA', 'COMERCIAL', 3.3700, true, '12/01/26'),
  ('cpr_victor_alcala_aluminio', 'VICTOR ALCALA', 'ALUMINIO', 'COMERCIAL', 33.5000, true, null),
  ('cpr_victor_garcia_aluminio', 'VICTOR GARCIA', 'ALUMINIO', 'COMERCIAL', 26.0000, true, 'AUT LUIS 17/03/2026'),
  ('cpr_victor_garcia_arbol_de_levas', 'VICTOR GARCIA', 'ARBOL DE LEVAS', 'COMERCIAL', 5.0500, true, '11/06/23 0:00'),
  ('cpr_victor_garcia_carton_coresba', 'VICTOR GARCIA', 'CARTON CORESBA', 'COMERCIAL', 1.3000, true, '14/11/2025 baja 0.20 12/12/2025 baja 0.20 22/12/2025, BAJA .20 CENTAVOS 03/01/2026, BAJA .10 CENTAVOS 10/02/2026, BAJA .30 CENTAVOS 16/02/2026, SUBE .10 CENTAVOS 19/02/2026, SUBE .10 CENTAVOS 19/03/2026, 10 CENTAVOS AUT LUIS 27/03/2026'),
  ('cpr_victor_garcia_carton_fortaleza', 'VICTOR GARCIA', 'CARTON FORTALEZA', 'COMERCIAL', 1.3000, true, '05-03-2025 baja 0.20 12/12/2025 baja 0.20 22/12/2025, BAJA .20 CENTAVOS 03/01/2026, BAJA .10 CENTAVOS 10/02/2026, BAJA .30 CENTAVOS 16/02/2026, SUBE .10 CENTAVOS 19/02/2026, SUBE .10 CENTAVOS 19/03/2026, .10 CENTAVOS AUT LUIS 27/03/2026'),
  ('cpr_victor_garcia_carton_strokpack', 'VICTOR GARCIA', 'CARTON STROKPACK', 'COMERCIAL', 1.3000, true, 'BAJA 0.20 14/10/2025 baja 0.20 12/12/2025 baja 0.20 22/12/2025, BAJA .20 CENTAVOS 03/01/2026, BAJA .10 CENTAVOS 10/02/2026, BAJA .30 CENTAVOS 16/02/2026, SUBE  .10 CENTAVOS 19/02/2026, SUBE .10 CENTAVOS 19/03/2026, .10 CENTAVOS AUT LUIS 27/03/2026'),
  ('cpr_victor_garcia_chatarra_carrocerias_halcon', 'VICTOR GARCIA', 'CHATARRA CARROCERIAS HALCON', 'COMERCIAL', 3.5500, true, '12/08/2025, BAJA .15 CENTAVOS 24/03/2026, BAJA .40 CENTAVOS 27/04/2026'),
  ('cpr_victor_garcia_chatarra_coresba', 'VICTOR GARCIA', 'CHATARRA CORESBA', 'COMERCIAL', 3.8500, true, 'BAJA .15 CENTAVOS 24/03/2026, BAJA .40 CENTAVOS 27/04/2026'),
  ('cpr_victor_garcia_chatarra_ferrebaztan', 'VICTOR GARCIA', 'CHATARRA FERREBAZTAN', 'COMERCIAL', 5.1000, true, 'BAJA .40 CENTAVOS 10/03/2026, BAJA .40 CENTAVOS 18/03/2026, BAJA .15 CENTAVOS 24/03/2026, AJUSTE .40 CENTAVOS, BAJA .40 CENTAVOS 06/04/2026, BAJA .40 CENTAVOS 27/04/2026, SUBE 06/05/2026 0.20 CENTAVOS, SUBE 19/05/2026 0.20 CENTAVOS'),
  ('cpr_victor_garcia_chatarra_tresguerras', 'VICTOR GARCIA', 'CHATARRA TRESGUERRAS', 'COMERCIAL', 3.5500, true, 'BAJA .15 CENTAVOS 24/03/2026, BAJA .40 CENTAVOS 27/04/2026'),
  ('cpr_victor_garcia_chatarra_victor_garcia', 'VICTOR GARCIA', 'CHATARRA VICTOR GARCIA', 'COMERCIAL', 5.1000, true, 'BAJA .40 CENTAVOS 10/03/2026, BAJA .40 CENTAVOS 18/03/2026, BAJA .15 CENTAVOS 24/03/2026, BAJA .40 CENTAVOS 27/04/2026, SUBE 06/05/2026 0.20 CENTAVOS, SUBE 19/05/2026 0.20 CENTAVOS'),
  ('cpr_victor_garcia_placa_y_estructura', 'VICTOR GARCIA', 'PLACA Y ESTRUCTURA', 'COMERCIAL', 4.6500, true, '10/10/2023 00:00:00, BAJA .40 CENTAVOS 10/03/2026, BAJA .40 CENTAVOS 18/03/2026, BAJA .15 CENTAVOS 24/03/2026, BAJA .40 CENTAVOS 27/04/2026, SUBE 06/05/2026 0.20 CENTAVOS, SUBE 19/05/2026 0.20 CENTAVOS'),
  ('cpr_victor_garcia_rebaba', 'VICTOR GARCIA', 'REBABA', 'COMERCIAL', 3.7000, true, '10/17/2023 00:00:00, BAJA .40 CENTAVOS 10/03/2026, BAJA .40 CENTAVOS 18/03/2026, BAJA .15 CENTAVOS 24/03/2026, BAJA .40 CENTAVOS 27/04/2026, SUBE 06/05/2026 0.20 CENTAVOS, SUBE 19/05/2026 0.20 CENTAVOS'),
  ('cpr_whirlpool_botellas_pet', 'WHIRLPOOL', 'BOTELLAS PET', 'COMERCIAL', 0.5000, true, '12/05/23 0:00'),
  ('cpr_whirlpool_cable_arnes_electrico', 'WHIRLPOOL', 'CABLE ARNES ELECTRICO', 'COMERCIAL', 10.0000, true, '12/05/23 0:00'),
  ('cpr_whirlpool_carton', 'WHIRLPOOL', 'CARTON', 'COMERCIAL', 0.4000, true, '12/05/23 0:00'),
  ('cpr_whirlpool_charola_pet', 'WHIRLPOOL', 'CHAROLA PET', 'COMERCIAL', 0.5000, true, '12/05/23 0:00'),
  ('cpr_whirlpool_cubetas_de_plastico', 'WHIRLPOOL', 'CUBETAS DE PLASTICO', 'COMERCIAL', 2.5000, true, '12/05/23 0:00'),
  ('cpr_whirlpool_madera_tarimas_120_x_100', 'WHIRLPOOL', 'MADERA TARIMAS 120 X 100', 'COMERCIAL', 0.4500, true, '12/05/23 0:00'),
  ('cpr_whirlpool_maquinaria_chatarra', 'WHIRLPOOL', 'MAQUINARIA CHATARRA', 'COMERCIAL', 4.0000, true, null),
  ('cpr_whirlpool_papel', 'WHIRLPOOL', 'PAPEL', 'COMERCIAL', 0.4000, true, '12/05/23 0:00'),
  ('cpr_whirlpool_pedaceria_madera', 'WHIRLPOOL', 'PEDACERIA MADERA', 'COMERCIAL', 0.0000, true, null),
  ('cpr_whirlpool_poliestireno_rigido_plastico_rigido', 'WHIRLPOOL', 'POLIESTIRENO RIGIDO PLASTICO RIGIDO', 'COMERCIAL', 0.5000, true, '12/04/23 0:00'),
  ('cpr_whirlpool_polietileno', 'WHIRLPOOL', 'POLIETILENO', 'COMERCIAL', 0.5000, true, '12/04/23 0:00'),
  ('cpr_whirlpool_polietileno_de_baja_densidad_polifoam', 'WHIRLPOOL', 'POLIETILENO DE BAJA DENSIDAD POLIFOAM', 'COMERCIAL', 0.5000, true, '12/05/23 0:00'),
  ('cpr_whirlpool_residuos_electronicos', 'WHIRLPOOL', 'RESIDUOS ELECTRONICOS', 'COMERCIAL', 0.5000, true, '12/05/23 0:00'),
  ('cpr_whirlpool_tambos_metalicos', 'WHIRLPOOL', 'TAMBOS METALICOS', 'COMERCIAL', 30.0000, true, '12/05/23 0:00'),
  ('cpr_whirlpool_tambos_plastico', 'WHIRLPOOL', 'TAMBOS PLASTICO', 'COMERCIAL', 50.0000, true, '12/05/23 0:00'),
  ('cpr_whirlpool_unicel', 'WHIRLPOOL', 'UNICEL', 'COMERCIAL', 0.0000, true, '12/04/23 0:00'),
  ('cpr_yorozu_acero', 'YOROZU', 'ACERO', 'COMERCIAL', 2.8000, true, null),
  ('cpr_yorozu_aluminio', 'YOROZU', 'ALUMINIO', 'COMERCIAL', 15.0000, true, null),
  ('cpr_yorozu_basura', 'YOROZU', 'BASURA', 'COMERCIAL', 0.2800, true, null),
  ('cpr_yorozu_bronces_sucio', 'YOROZU', 'BRONCES SUCIO', 'COMERCIAL', 15.0000, true, null),
  ('cpr_yorozu_carton', 'YOROZU', 'CARTON', 'COMERCIAL', 0.5000, true, null),
  ('cpr_yorozu_cobre_sucio', 'YOROZU', 'COBRE SUCIO', 'COMERCIAL', 55.0000, true, null),
  ('cpr_yorozu_electronicos', 'YOROZU', 'ELECTRONICOS', 'COMERCIAL', 15.0000, true, null),
  ('cpr_yorozu_madera', 'YOROZU', 'MADERA', 'COMERCIAL', 0.0000, true, null),
  ('cpr_yorozu_plastico', 'YOROZU', 'PLASTICO', 'COMERCIAL', 1.5000, true, null),
  ('cpr_yorozu_plolietileno', 'YOROZU', 'PLOLIETILENO', 'COMERCIAL', 2.0000, true, null),
  ('cpr_yorozu_tambos_de_carton', 'YOROZU', 'TAMBOS DE CARTON', 'COMERCIAL', 5.0000, true, null);

insert into public.compras_counterparty_material_prices (
  id,
  company_id,
  material_id,
  final_price,
  is_active,
  notes
)
select
  src.id,
  company.id,
  material.id,
  src.final_price,
  src.is_active,
  src.notes
from tmp_import_compras_prices src
join public.compras_counterparties company
  on upper(company.name) = upper(src.company_name)
join public.compras_material_catalog material
  on upper(material.name) = upper(src.material_name)
 and material.level = src.material_level
on conflict (company_id, material_id) do update
set
  final_price = excluded.final_price,
  is_active = excluded.is_active,
  notes = excluded.notes;

commit;
