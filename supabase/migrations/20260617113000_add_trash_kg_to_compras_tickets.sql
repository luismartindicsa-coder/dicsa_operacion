alter table public.compras_tickets
  add column if not exists trash_kg numeric(14,3),
  add column if not exists trash_capture_mode text;

update public.compras_tickets
set
  trash_kg = coalesce(trash_kg, 0),
  trash_capture_mode = coalesce(nullif(btrim(trash_capture_mode), ''), 'PERCENT')
where trash_kg is null
   or trash_capture_mode is null
   or btrim(trash_capture_mode) = '';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'compras_tickets_trash_capture_mode_chk'
  ) then
    alter table public.compras_tickets
      add constraint compras_tickets_trash_capture_mode_chk
      check (trash_capture_mode in ('PERCENT', 'KG'));
  end if;
end
$$;

alter table public.compras_tickets
  alter column trash_kg set default 0,
  alter column trash_kg set not null,
  alter column trash_capture_mode set default 'KG',
  alter column trash_capture_mode set not null;
