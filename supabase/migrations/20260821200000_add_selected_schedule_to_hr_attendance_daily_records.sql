alter table public.hr_attendance_daily_records
  add column if not exists selected_schedule text not null default '';

comment on column public.hr_attendance_daily_records.selected_schedule is
  'Horario de Personal elegido por RH para ese colaborador y día; conserva la jornada histórica de turnos rotativos.';
