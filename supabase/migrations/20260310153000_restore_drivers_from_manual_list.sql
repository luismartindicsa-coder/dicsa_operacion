begin;

insert into public.employees (full_name, is_driver, is_active)
select v.full_name, true, true
from (
  values
    ('Gabriel Rodriguez'),
    ('Angel Lopez'),
    ('Luis Angel Centeno'),
    ('Eduardo Montes'),
    ('Javier Ayala'),
    ('Martin Rodriguez'),
    ('Daniel Garcia'),
    ('Francisco Guerrero'),
    ('Hugo Garcia'),
    ('Manuel Pavana'),
    ('Javier Martinez'),
    ('Jesus Rodriguez'),
    ('Rene Jimenez'),
    ('Jesus Cienega'),
    ('Rigoberto Castro'),
    ('Rigoberto Gonzales'),
    ('Adrian Moran')
) as v(full_name)
where not exists (
  select 1
  from public.employees e
  where upper(btrim(e.full_name)) = upper(btrim(v.full_name))
);

commit;
