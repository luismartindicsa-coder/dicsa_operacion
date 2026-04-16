-- Recuperacion parcial desde backup de corte 2026-03-31
-- Estrategia: apertura general + transformaciones sinteticas
begin;

-- CHATARRA
insert into public.inventory_opening_balances_v2 (
  period_month,
  as_of_date,
  inventory_level,
  general_material_id,
  weight_kg,
  unit_count,
  site,
  notes
)
values (
  '2026-04-01',
  '2026-04-01',
  'GENERAL',
  '4c7a25df-991f-4443-9269-4e853df6fed3',
  95689.200,
  null,
  'DICSA_CELAYA',
  'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | APERTURA GENERAL CHATARRA'
);

with inserted_run as (
  insert into public.material_transformation_runs_v2 (
    op_date,
    shift,
    source_general_material_id,
    input_weight_kg,
    site,
    notes
  )
  values (
    '2026-04-01',
    'DAY',
    '4c7a25df-991f-4443-9269-4e853df6fed3',
    20000.000,
    'DICSA_CELAYA',
    'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | TRANSFORMACION SINTETICA CHATARRA->RACKS'
  )
  returning id
)
insert into public.material_transformation_run_outputs_v2 (
  run_id,
  commercial_material_id,
  output_weight_kg,
  output_unit_count,
  notes
)
select
  id,
  '261d3133-a8aa-4466-9e39-008f8fbe0386',
  20000.000,
  null,
  'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | TRANSFORMACION SINTETICA CHATARRA->RACKS'
from inserted_run;

with inserted_run as (
  insert into public.material_transformation_runs_v2 (
    op_date,
    shift,
    source_general_material_id,
    input_weight_kg,
    site,
    notes
  )
  values (
    '2026-04-01',
    'DAY',
    '4c7a25df-991f-4443-9269-4e853df6fed3',
    17390.000,
    'DICSA_CELAYA',
    'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | TRANSFORMACION SINTETICA CHATARRA->LAMINA'
  )
  returning id
)
insert into public.material_transformation_run_outputs_v2 (
  run_id,
  commercial_material_id,
  output_weight_kg,
  output_unit_count,
  notes
)
select
  id,
  'eaaa8aa0-69bc-4633-9e82-46ae02473f3f',
  17390.000,
  null,
  'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | TRANSFORMACION SINTETICA CHATARRA->LAMINA'
from inserted_run;

with inserted_run as (
  insert into public.material_transformation_runs_v2 (
    op_date,
    shift,
    source_general_material_id,
    input_weight_kg,
    site,
    notes
  )
  values (
    '2026-04-01',
    'DAY',
    '4c7a25df-991f-4443-9269-4e853df6fed3',
    15000.000,
    'DICSA_CELAYA',
    'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | TRANSFORMACION SINTETICA CHATARRA->PESADO'
  )
  returning id
)
insert into public.material_transformation_run_outputs_v2 (
  run_id,
  commercial_material_id,
  output_weight_kg,
  output_unit_count,
  notes
)
select
  id,
  '47193986-3a6a-467e-8616-656ae4cae977',
  15000.000,
  null,
  'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | TRANSFORMACION SINTETICA CHATARRA->PESADO'
from inserted_run;

with inserted_run as (
  insert into public.material_transformation_runs_v2 (
    op_date,
    shift,
    source_general_material_id,
    input_weight_kg,
    site,
    notes
  )
  values (
    '2026-04-01',
    'DAY',
    '4c7a25df-991f-4443-9269-4e853df6fed3',
    7000.000,
    'DICSA_CELAYA',
    'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | TRANSFORMACION SINTETICA CHATARRA->RETORNO_INDUSTRIAL'
  )
  returning id
)
insert into public.material_transformation_run_outputs_v2 (
  run_id,
  commercial_material_id,
  output_weight_kg,
  output_unit_count,
  notes
)
select
  id,
  '9950e351-6716-4caa-a6e5-dfccf2513529',
  7000.000,
  null,
  'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | TRANSFORMACION SINTETICA CHATARRA->RETORNO_INDUSTRIAL'
from inserted_run;

with inserted_run as (
  insert into public.material_transformation_runs_v2 (
    op_date,
    shift,
    source_general_material_id,
    input_weight_kg,
    site,
    notes
  )
  values (
    '2026-04-01',
    'DAY',
    '4c7a25df-991f-4443-9269-4e853df6fed3',
    3485.800,
    'DICSA_CELAYA',
    'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | TRANSFORMACION SINTETICA CHATARRA->ACERO_CHATARRA'
  )
  returning id
)
insert into public.material_transformation_run_outputs_v2 (
  run_id,
  commercial_material_id,
  output_weight_kg,
  output_unit_count,
  notes
)
select
  id,
  'f51adf9d-1e04-4b45-a996-74b217b499fa',
  3485.800,
  null,
  'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | TRANSFORMACION SINTETICA CHATARRA->ACERO_CHATARRA'
from inserted_run;

with inserted_run as (
  insert into public.material_transformation_runs_v2 (
    op_date,
    shift,
    source_general_material_id,
    input_weight_kg,
    site,
    notes
  )
  values (
    '2026-04-01',
    'DAY',
    '4c7a25df-991f-4443-9269-4e853df6fed3',
    2000.000,
    'DICSA_CELAYA',
    'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | TRANSFORMACION SINTETICA CHATARRA->PLACA_Y_ESTRUCTURA_LARGA'
  )
  returning id
)
insert into public.material_transformation_run_outputs_v2 (
  run_id,
  commercial_material_id,
  output_weight_kg,
  output_unit_count,
  notes
)
select
  id,
  'f05eb20f-5e8c-40ab-88f0-907bdf3a5431',
  2000.000,
  null,
  'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | TRANSFORMACION SINTETICA CHATARRA->PLACA_Y_ESTRUCTURA_LARGA'
from inserted_run;

with inserted_run as (
  insert into public.material_transformation_runs_v2 (
    op_date,
    shift,
    source_general_material_id,
    input_weight_kg,
    site,
    notes
  )
  values (
    '2026-04-01',
    'DAY',
    '4c7a25df-991f-4443-9269-4e853df6fed3',
    356.600,
    'DICSA_CELAYA',
    'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | TRANSFORMACION SINTETICA CHATARRA->MIXTO'
  )
  returning id
)
insert into public.material_transformation_run_outputs_v2 (
  run_id,
  commercial_material_id,
  output_weight_kg,
  output_unit_count,
  notes
)
select
  id,
  '912e86e8-a6b4-4c01-9d9e-fe16c3d7d4d8',
  356.600,
  null,
  'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | TRANSFORMACION SINTETICA CHATARRA->MIXTO'
from inserted_run;

with inserted_run as (
  insert into public.material_transformation_runs_v2 (
    op_date,
    shift,
    source_general_material_id,
    input_weight_kg,
    site,
    notes
  )
  values (
    '2026-04-01',
    'DAY',
    '4c7a25df-991f-4443-9269-4e853df6fed3',
    80.000,
    'DICSA_CELAYA',
    'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | TRANSFORMACION SINTETICA CHATARRA->REBABA'
  )
  returning id
)
insert into public.material_transformation_run_outputs_v2 (
  run_id,
  commercial_material_id,
  output_weight_kg,
  output_unit_count,
  notes
)
select
  id,
  '1f9d57fb-c379-46df-94f7-f93d82d67843',
  80.000,
  null,
  'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | TRANSFORMACION SINTETICA CHATARRA->REBABA'
from inserted_run;

-- METAL
insert into public.inventory_opening_balances_v2 (
  period_month,
  as_of_date,
  inventory_level,
  general_material_id,
  weight_kg,
  unit_count,
  site,
  notes
)
values (
  '2026-04-01',
  '2026-04-01',
  'GENERAL',
  'a3b39add-83a8-4b9e-92db-242b2b852a40',
  8746.400,
  null,
  'DICSA_CELAYA',
  'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | APERTURA GENERAL METAL'
);

-- PAPEL
insert into public.inventory_opening_balances_v2 (
  period_month,
  as_of_date,
  inventory_level,
  general_material_id,
  weight_kg,
  unit_count,
  site,
  notes
)
values (
  '2026-04-01',
  '2026-04-01',
  'GENERAL',
  '97e156d5-3719-4083-885c-e6a25af94015',
  1985.600,
  null,
  'DICSA_CELAYA',
  'RECUPERACION DESDE BACKUP CORTE 2026-03-31 | APERTURA GENERAL PAPEL'
);

commit;
