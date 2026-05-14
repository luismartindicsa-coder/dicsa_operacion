create temporary table tmp_operation_directory_seed (
  name text not null,
  areas text[] not null default '{}',
  specialties text[] not null default '{}',
  availability text,
  contact text,
  quotes boolean not null default true,
  visit_cost numeric(12,2),
  warranty text,
  comments text
) on commit drop;

insert into tmp_operation_directory_seed (
  name,
  areas,
  specialties,
  availability,
  contact,
  quotes,
  visit_cost,
  warranty,
  comments
)
values
  (
    'JESUS GARCIA',
    ARRAY['FLOTILLA'],
    ARRAY['TALACHERO', 'CAMBIO DE LLANTAS', 'REPARACION DE RESCATES'],
    'TALACHAS INMEDIATA, RESCATES Y REPARACIONES SE PROGRAMAN',
    '4613181095',
    true,
    200.00,
    null,
    '$200 CAMBIO DE LLANTA'
  ),
  (
    'JOSE JUAN ARELLANO',
    ARRAY['FLOTILLA', 'FABRICAS', 'PATIO'],
    ARRAY[
      'ACCESO A WHIRPOOL',
      'HIDRAULICA',
      'SOLDADURA',
      'TRABAJO EN ALTURA',
      'FABRICACION DE MAQUINARIA',
      'ELECTRICIDAD'
    ],
    'DIAGNOSTICO INMEDIATO, SE PROGRAMAN LAS REPARACIONES',
    '4611802930',
    true,
    null,
    'OFRECE GARANTIA',
    'Costo por visita reportado como: NINGUNO AL ADQUIRIR EL SERVICIO'
  ),
  (
    'MORE',
    ARRAY['FLOTILLA'],
    ARRAY['ELECTRICO AUTOMOTRIZ'],
    'INMEDIATA',
    '4611778340',
    false,
    300.00,
    null,
    null
  ),
  (
    'ANTONIO SALDIVAR',
    ARRAY[]::text[],
    ARRAY[]::text[],
    null,
    null,
    true,
    null,
    null,
    'Registro migrado con información incompleta desde la lista original.'
  ),
  (
    'GIL',
    ARRAY['FABRICAS', 'PATIO'],
    ARRAY[
      'PLOMERIA',
      'ELECTRICISTA',
      'IMPERMEABILIZACION',
      'MANTENIMIENTO PREVENTIVO',
      'MANTENIMIENTO CORRECTIVO',
      'REPARACION DE GRUA'
    ],
    'INMEDIATA',
    '4613796758',
    true,
    null,
    null,
    'Costo por visita reportado como: NO'
  ),
  (
    'JUAN',
    ARRAY['FLOTILLA'],
    ARRAY['MECANICO'],
    null,
    '4611349778',
    true,
    null,
    null,
    null
  ),
  (
    'ISSAC TORRES',
    ARRAY['FLOTILLA', 'PATIO'],
    ARRAY['MUELLES', 'SOLDADURA'],
    'INMEDIATA',
    '4613923250',
    true,
    null,
    null,
    'Costo por visita reportado como: NO'
  ),
  (
    'MIGUEL AMADOR',
    ARRAY[]::text[],
    ARRAY[]::text[],
    null,
    '4613063673',
    true,
    null,
    null,
    'Registro migrado con información mínima; falta clasificar área y especialidad.'
  ),
  (
    'ROGELIO MARTINEZ',
    ARRAY['FLOTILLA'],
    ARRAY['MECANICO', 'LLANTAS', 'ACEITE', 'SERVICIO DE UNIDADES'],
    'INMEDIATA',
    '4613051130',
    true,
    null,
    null,
    'Costo por visita reportado como: NO'
  ),
  (
    'SR. MARCIANO',
    ARRAY['FLOTILLA', 'PATIO'],
    ARRAY['HIDRAULICO'],
    'CON CITA',
    '4423058452',
    false,
    null,
    null,
    'Costo por visita reportado como: NO'
  ),
  (
    'GILBERTO BRISEÑO',
    ARRAY['FABRICAS', 'PATIO'],
    ARRAY[
      'REPARACION DE BOMBAS',
      'MOTORES',
      'TRANSFORMADORES',
      'MANTENIMIENTO CORRECTIVO',
      'MANTENIMIENTO PREVENTIVO',
      'SUBESTACIONES',
      'INSTALACIONES ELECTRICAS'
    ],
    'CON CITA',
    '4613987445',
    true,
    null,
    'OFRECE GARANTIA',
    'Costo por visita reportado como: NO'
  ),
  (
    'ARMANDO LOPEZ',
    ARRAY['FABRICAS', 'OFICINA', 'PATIO'],
    ARRAY['CAMARAS', 'SISTEMAS DE SEGURIDAD', 'INSTALACION', 'REPARACION'],
    'CON CITA',
    '4611260816',
    true,
    null,
    'OFRECE GARANTIA',
    null
  ),
  (
    'SOCORRO ARELLANO',
    ARRAY['FLOTILLA', 'PATIO'],
    ARRAY['HIDRAULICO'],
    'INMEDIATA',
    '4613171644',
    true,
    null,
    'OFRECE GARANTIA',
    'Costo por visita reportado como: NO'
  ),
  (
    'ISMAEL',
    ARRAY['FLOTILLA', 'PATIO'],
    ARRAY['HOJALATERIA', 'PINTURA'],
    'CON CITA',
    '4613363383',
    true,
    null,
    null,
    null
  ),
  (
    'DANIEL SALINAS',
    ARRAY['FLOTILLA'],
    ARRAY['TAPICERIA'],
    'CON CITA',
    '4613488851',
    true,
    null,
    null,
    null
  ),
  (
    'HIDRAULICA DIERKA',
    ARRAY['FLOTILLA', 'PATIO'],
    ARRAY['HIDRAULICA ESPECIALIZADA'],
    'CON CITA',
    '4772026511',
    true,
    null,
    null,
    null
  ),
  (
    'OMAR GARCIA (SIMMUS INGENIERIA)',
    ARRAY['FABRICAS', 'PATIO'],
    ARRAY['HIDRAULICA', 'OBRA CIVIL'],
    'CON CITA',
    '4423832056',
    true,
    null,
    'OFRECE GARANTIA',
    'Costo por visita reportado como: NO'
  ),
  (
    'ROBERTO HERNANDEZ',
    ARRAY['FABRICAS', 'PATIO'],
    ARRAY['ESTRUCTURAS', 'TECHOS'],
    'CON CITA',
    '4611086672',
    true,
    null,
    null,
    'TIENE PENDIENTE ENTREGAR UN TRABAJO'
  );

update public.operation_directory_contacts c
set
  area = case
    when cardinality(s.areas) = 0 then null
    else array_to_string(s.areas, ', ')
  end,
  specialty = case
    when cardinality(s.specialties) = 0 then null
    else array_to_string(s.specialties, ', ')
  end,
  availability = s.availability,
  contact = s.contact,
  quotes = s.quotes,
  visit_cost = s.visit_cost,
  warranty = s.warranty,
  comments = s.comments,
  active = true,
  updated_at = now()
from tmp_operation_directory_seed s
where lower(c.name) = lower(s.name);

insert into public.operation_directory_contacts(
  name,
  area,
  specialty,
  availability,
  contact,
  quotes,
  visit_cost,
  warranty,
  comments,
  active
)
select
  s.name,
  case
    when cardinality(s.areas) = 0 then null
    else array_to_string(s.areas, ', ')
  end,
  case
    when cardinality(s.specialties) = 0 then null
    else array_to_string(s.specialties, ', ')
  end,
  s.availability,
  s.contact,
  s.quotes,
  s.visit_cost,
  s.warranty,
  s.comments,
  true
from tmp_operation_directory_seed s
where not exists (
  select 1
  from public.operation_directory_contacts c
  where lower(c.name) = lower(s.name)
);

insert into public.operation_directory_areas(name, active)
select distinct trim(area_name), true
from tmp_operation_directory_seed s
cross join lateral unnest(s.areas) area_name
where trim(area_name) <> ''
on conflict (name) do update
  set active = true,
      updated_at = now();

insert into public.operation_directory_specialties(name, active)
select distinct trim(specialty_name), true
from tmp_operation_directory_seed s
cross join lateral unnest(s.specialties) specialty_name
where trim(specialty_name) <> ''
on conflict (name) do update
  set active = true,
      updated_at = now();

delete from public.operation_directory_contact_areas
where contact_id in (
  select c.id
  from public.operation_directory_contacts c
  join tmp_operation_directory_seed s
    on lower(c.name) = lower(s.name)
);

insert into public.operation_directory_contact_areas(contact_id, area_id)
select distinct
  c.id,
  a.id
from public.operation_directory_contacts c
join tmp_operation_directory_seed s
  on lower(c.name) = lower(s.name)
cross join lateral unnest(s.areas) area_name
join public.operation_directory_areas a
  on a.name = trim(area_name)
where trim(area_name) <> ''
on conflict do nothing;

delete from public.operation_directory_contact_specialties
where contact_id in (
  select c.id
  from public.operation_directory_contacts c
  join tmp_operation_directory_seed s
    on lower(c.name) = lower(s.name)
);

insert into public.operation_directory_contact_specialties(contact_id, specialty_id)
select distinct
  c.id,
  sp.id
from public.operation_directory_contacts c
join tmp_operation_directory_seed s
  on lower(c.name) = lower(s.name)
cross join lateral unnest(s.specialties) specialty_name
join public.operation_directory_specialties sp
  on sp.name = trim(specialty_name)
where trim(specialty_name) <> ''
on conflict do nothing;
