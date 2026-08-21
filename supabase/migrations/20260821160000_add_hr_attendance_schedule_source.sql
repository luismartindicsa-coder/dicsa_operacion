alter table public.hr_attendance_daily_records
  drop constraint if exists hr_attendance_daily_records_source_mode_check;

alter table public.hr_attendance_daily_records
  add constraint hr_attendance_daily_records_source_mode_check
    check (source_mode in ('importado', 'jornada', 'manual', 'ajuste'));

comment on column public.hr_attendance_daily_records.source_mode is
  'Origen del día: importado (NGTeco), jornada (plantilla de Personal), manual o ajuste RH.';
