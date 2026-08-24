alter table public.hr_attendance_daily_records
  add column if not exists capture_origin text not null default 'weekly';

alter table public.hr_attendance_daily_records
  drop constraint if exists hr_attendance_daily_records_capture_origin_check;

alter table public.hr_attendance_daily_records
  add constraint hr_attendance_daily_records_capture_origin_check
  check (capture_origin in ('weekly', 'daily'));

comment on column public.hr_attendance_daily_records.capture_origin is
  'Superficie que realizó la última edición humana del día: semanal o diario.';
