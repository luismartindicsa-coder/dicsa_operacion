begin;

alter table public.logistics_diesel_consumption
  alter column operator_name drop not null,
  alter column vehicle_label drop not null;

alter table public.logistics_diesel_consumption
  drop constraint if exists logistics_diesel_operator_name_trim_chk,
  drop constraint if exists logistics_diesel_vehicle_label_trim_chk;

alter table public.logistics_diesel_consumption
  add constraint logistics_diesel_operator_name_trim_chk check (
    operator_name is null or (
      operator_name = btrim(operator_name) and length(operator_name) > 0
    )
  ),
  add constraint logistics_diesel_vehicle_label_trim_chk check (
    vehicle_label is null or (
      vehicle_label = btrim(vehicle_label) and length(vehicle_label) > 0
    )
  );

commit;
