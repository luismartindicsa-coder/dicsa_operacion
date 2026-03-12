begin;

create or replace function public.fn_set_production_source_bulk()
returns trigger
language plpgsql
as $$
begin
  if new.bale_material is null then
    return new;
  end if;

  case upper(new.bale_material::text)
    when 'BALE_AMERICAN' then
      new.source_bulk := 'CARDBOARD_BULK_AMERICAN'::public.inv_material;
    when 'CAPLE' then
      new.source_bulk := 'CAPLE'::public.inv_material;
    else
      new.source_bulk := 'CARDBOARD_BULK_NATIONAL'::public.inv_material;
  end case;

  return new;
end
$$;

drop trigger if exists trg_set_production_source_bulk on public.production_runs;

create trigger trg_set_production_source_bulk
before insert or update of bale_material, source_bulk
on public.production_runs
for each row
execute function public.fn_set_production_source_bulk();

alter table if exists public.production_runs
  drop constraint if exists production_runs_source_bulk_check;

alter table if exists public.production_runs
  add constraint production_runs_source_bulk_check
  check (
    (
      bale_material = 'BALE_AMERICAN'
      and source_bulk in ('CARDBOARD_BULK_AMERICAN', 'CARDBOARD_BULK_NATIONAL')
    )
    or (
      bale_material in ('BALE_NATIONAL', 'BALE_CLEAN', 'BALE_TRASH')
      and source_bulk = 'CARDBOARD_BULK_NATIONAL'
    )
    or (
      bale_material = 'CAPLE'
      and source_bulk = 'CAPLE'
    )
  );

update public.production_runs
   set source_bulk = case upper(coalesce(bale_material::text, ''))
     when 'BALE_AMERICAN' then 'CARDBOARD_BULK_AMERICAN'::public.inv_material
     when 'CAPLE' then 'CAPLE'::public.inv_material
     else 'CARDBOARD_BULK_NATIONAL'::public.inv_material
   end
 where source_bulk is distinct from case upper(coalesce(bale_material::text, ''))
   when 'BALE_AMERICAN' then 'CARDBOARD_BULK_AMERICAN'::public.inv_material
   when 'CAPLE' then 'CAPLE'::public.inv_material
   else 'CARDBOARD_BULK_NATIONAL'::public.inv_material
 end;

commit;
