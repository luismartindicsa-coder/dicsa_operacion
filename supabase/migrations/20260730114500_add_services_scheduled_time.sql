alter table public.services
  add column if not exists scheduled_time time without time zone;

comment on column public.services.scheduled_time is
  'Hora programada del servicio para la planeacion diaria de Logistica.';

update public.services
set scheduled_time = case
  when lower(coalesce(status::text, '')) in ('en_ruta', 'en sitio', 'en_sitio', 'ensitio')
    then '07:30:00'::time
  when lower(coalesce(direction::text, '')) = 'recoleccion'
    then '08:00:00'::time
  when lower(coalesce(direction::text, '')) = 'entrega'
    then '10:00:00'::time
  else '09:00:00'::time
end
where scheduled_time is null
  and upper(coalesce(area, '')) = 'LOGISTICA';
