begin;

alter table public.logistics_vehicle_profiles
  add column model_year integer,
  add column model_name text,
  add constraint logistics_vehicle_profiles_model_year_chk
    check (model_year is null or model_year between 1900 and 2100);

comment on column public.logistics_vehicle_profiles.model_year is
  'Año de la unidad. Opcional; NULL si aún no se captura.';
comment on column public.logistics_vehicle_profiles.model_name is
  'Modelo de la unidad capturado en el perfil logístico. Opcional.';

commit;
