create or replace function public.fn_set_production_source_bulk()
returns trigger
language plpgsql
as $$
begin
  if new.bale_material is null then
    return new;
  end if;

  case new.bale_material
    when 'BALE_AMERICAN' then
      new.source_bulk := 'CARDBOARD_BULK_AMERICAN';
    when 'CAPLE' then
      new.source_bulk := 'CAPLE';
    else
      new.source_bulk := 'CARDBOARD_BULK_NATIONAL';
  end case;

  return new;
end;
$$;

drop trigger if exists trg_set_production_source_bulk on public.production_runs;

create trigger trg_set_production_source_bulk
before insert or update of bale_material, source_bulk
on public.production_runs
for each row
execute function public.fn_set_production_source_bulk();

update public.production_runs
set source_bulk = case bale_material
  when 'BALE_AMERICAN' then 'CARDBOARD_BULK_AMERICAN'::inv_material
  when 'CAPLE' then 'CAPLE'::inv_material
  else 'CARDBOARD_BULK_NATIONAL'::inv_material
end
where source_bulk is distinct from case bale_material
  when 'BALE_AMERICAN' then 'CARDBOARD_BULK_AMERICAN'::inv_material
  when 'CAPLE' then 'CAPLE'::inv_material
  else 'CARDBOARD_BULK_NATIONAL'::inv_material
end;
