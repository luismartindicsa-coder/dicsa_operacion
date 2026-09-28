begin;

-- Forecast allocation only: does not record or change actual collections.
create table public.direction_income_allocations (
  shipment_id uuid primary key references public.direction_shipment_plans(id) on delete cascade,
  source_key text not null check (length(source_key) between 1 and 4000),
  total_cents bigint not null check (total_cents between 1 and 100000000000000),
  cash_cents bigint not null check (cash_cents between 0 and 100000000000000),
  fiscal_cents bigint not null check (fiscal_cents between 0 and 100000000000000),
  revision integer not null check (revision > 0),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id),
  check (cash_cents + fiscal_cents = total_cents)
);
alter table public.direction_income_allocations enable row level security;
revoke all on public.direction_income_allocations from anon, authenticated;
grant select on public.direction_income_allocations to authenticated;
create policy direction_income_allocation_read on public.direction_income_allocations
  for select to authenticated using (public.direction_program_can_manage());

create function public.direction_income_save_allocation(
  p_shipment_id uuid, p_source_key text, p_total_cents numeric,
  p_cash_cents numeric, p_fiscal_cents numeric, p_expected_revision integer
) returns jsonb language plpgsql security definer set search_path=public as $$
declare old_revision integer; saved public.direction_income_allocations;
begin
  if not coalesce(public.direction_program_can_manage(),false) then
    raise exception 'Sin permiso' using errcode='42501';
  end if;
  if p_shipment_id is null or p_source_key is null or length(btrim(p_source_key)) not between 1 and 4000
    or p_expected_revision is null or p_expected_revision < 0
    or p_total_cents is null or p_cash_cents is null or p_fiscal_cents is null
    or p_total_cents not between 1 and 100000000000000
    or p_cash_cents not between 0 and 100000000000000
    or p_fiscal_cents not between 0 and 100000000000000
    or p_total_cents <> trunc(p_total_cents) or p_cash_cents <> trunc(p_cash_cents)
    or p_fiscal_cents <> trunc(p_fiscal_cents)
    or p_cash_cents + p_fiscal_cents <> p_total_cents then
    raise exception 'Efectivo y Fiscal deben sumar exactamente el importe por distribuir.';
  end if;
  -- Serializes even the first save, and prevents deletion during the write.
  perform 1 from public.direction_shipment_plans where id=p_shipment_id for update;
  if not found then raise exception 'El embarque ya no existe.'; end if;
  select revision into old_revision from public.direction_income_allocations
    where shipment_id=p_shipment_id for update;
  if coalesce(old_revision,0) <> p_expected_revision then
    raise exception 'La distribución cambió en otra sesión. Cierra la edición y vuelve a abrirla para usar la versión actual.' using errcode='PT409';
  end if;
  insert into public.direction_income_allocations(shipment_id,source_key,total_cents,cash_cents,fiscal_cents,revision,updated_by)
    values(p_shipment_id,p_source_key,p_total_cents,p_cash_cents,p_fiscal_cents,p_expected_revision+1,auth.uid())
    on conflict(shipment_id) do update set source_key=excluded.source_key,total_cents=excluded.total_cents,
      cash_cents=excluded.cash_cents,fiscal_cents=excluded.fiscal_cents,revision=excluded.revision,
      updated_at=now(),updated_by=excluded.updated_by returning * into saved;
  return to_jsonb(saved);
end $$;
revoke all on function public.direction_income_save_allocation(uuid,text,numeric,numeric,numeric,integer) from public, anon;
grant execute on function public.direction_income_save_allocation(uuid,text,numeric,numeric,numeric,integer) to authenticated;

commit;
