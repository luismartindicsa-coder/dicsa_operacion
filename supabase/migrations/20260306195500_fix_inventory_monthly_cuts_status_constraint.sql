begin;

-- Normalize legacy status column and constraint so Almacen can persist monthly cuts.
alter table public.inventory_monthly_cuts
  alter column status type text using lower(status::text);

alter table public.inventory_monthly_cuts
  drop constraint if exists inventory_monthly_cuts_status_check;

update public.inventory_monthly_cuts
set status = case
  when status in ('open', 'opened', 'apertura', 'abierta') then 'abierto'
  when status in ('review', 'in_review', 'en-revision', 'revision') then 'en_revision'
  when status in ('closed', 'close', 'cierre', 'cerrada') then 'cerrado'
  else status
end;

update public.inventory_monthly_cuts
set status = 'abierto'
where status is null
   or btrim(status) = ''
   or status not in ('abierto', 'en_revision', 'cerrado');

alter table public.inventory_monthly_cuts
  add constraint inventory_monthly_cuts_status_check
  check (status in ('abierto', 'en_revision', 'cerrado'));

alter table public.inventory_monthly_cuts
  alter column status set default 'abierto';

commit;
