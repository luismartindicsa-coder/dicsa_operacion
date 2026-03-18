begin;

update public.employees
set full_name = upper(regexp_replace(btrim(full_name), '\s+', ' ', 'g'))
where full_name is not null
  and full_name is distinct from upper(regexp_replace(btrim(full_name), '\s+', ' ', 'g'));

update public.sites
set name = upper(regexp_replace(btrim(name), '\s+', ' ', 'g'))
where name is not null
  and name is distinct from upper(regexp_replace(btrim(name), '\s+', ' ', 'g'));

with ranked_employees as (
  select
    id,
    row_number() over (
      partition by upper(regexp_replace(btrim(full_name), '\s+', ' ', 'g'))
      order by created_at nulls last, id
    ) as rn
  from public.employees
  where full_name is not null
)
delete from public.employees e
using ranked_employees r
where e.id = r.id
  and r.rn > 1;

with ranked_sites as (
  select
    id,
    row_number() over (
      partition by upper(regexp_replace(btrim(name), '\s+', ' ', 'g'))
      order by created_at nulls last, id
    ) as rn
  from public.sites
  where name is not null
)
delete from public.sites s
using ranked_sites r
where s.id = r.id
  and r.rn > 1;

create unique index if not exists employees_full_name_normalized_uidx
  on public.employees ((upper(regexp_replace(btrim(full_name), '\s+', ' ', 'g'))));

create unique index if not exists sites_name_normalized_uidx
  on public.sites ((upper(regexp_replace(btrim(name), '\s+', ' ', 'g'))));

insert into public.employees (full_name, is_driver, is_active)
select v.full_name, true, true
from (
  values
    ('GABRIEL RODRIGUEZ'),
    ('ANGEL LOPEZ'),
    ('LUIS ANGEL CENTENO'),
    ('EDUARDO MONTES'),
    ('JAVIER AYALA'),
    ('MARTIN RODRIGUEZ'),
    ('DANIEL GARCIA'),
    ('FRANCISCO GUERRERO'),
    ('HUGO GARCIA'),
    ('MANUEL PAVANA'),
    ('JAVIER MARTINEZ'),
    ('JESUS RODRIGUEZ'),
    ('RENE JIMENEZ'),
    ('JESUS CIENEGA'),
    ('RIGOBERTO CASTRO'),
    ('RIGOBERTO GONZALES'),
    ('ADRIAN MORAN')
) as v(full_name)
where not exists (
  select 1
  from public.employees e
  where upper(regexp_replace(btrim(e.full_name), '\s+', ' ', 'g')) =
        upper(regexp_replace(btrim(v.full_name), '\s+', ' ', 'g'))
);

insert into public.sites (name, type, is_active)
select v.name, 'cliente', true
from (
  values
    ('MONROE'),
    ('MONROE SU'),
    ('DECASA'),
    ('WHIRLPOOL'),
    ('PARQUE AMIS'),
    ('AVON'),
    ('SETEX'),
    ('YOROZU'),
    ('JUAN SOLIS'),
    ('KS'),
    ('DE ACERO'),
    ('GRUPAK'),
    ('PARADO'),
    ('PATIO'),
    ('FALLA'),
    ('LUPITA'),
    ('ACROMA'),
    ('GKN'),
    ('ROCIO'),
    ('LICBOX'),
    ('SAN LUIS'),
    ('SAN PABLO'),
    ('TDF'),
    ('APASEO'),
    ('RODOLFO VE'),
    ('STANDART'),
    ('STROCK PAC'),
    ('FRIOCIMA'),
    ('MIGUEL AYAL'),
    ('JESUS CAMA'),
    ('CORESBA'),
    ('METAGRA'),
    ('LA FORTALEZ'),
    ('VILLAGRAN'),
    ('SERVIN'),
    ('PUBLICO'),
    ('RICARDO MENDIETA')
) as v(name)
where not exists (
  select 1
  from public.sites s
  where upper(regexp_replace(btrim(s.name), '\s+', ' ', 'g')) =
        upper(regexp_replace(btrim(v.name), '\s+', ' ', 'g'))
);

commit;
