begin;

create table if not exists public.pesadas (
  id uuid primary key default gen_random_uuid(),
  fecha date not null default current_date,
  ticket text not null,
  proveedor text not null,
  precio numeric(12,2) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists pesadas_fecha_idx on public.pesadas (fecha desc);
create index if not exists pesadas_ticket_idx on public.pesadas (ticket);
create index if not exists pesadas_proveedor_idx on public.pesadas (proveedor);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'pesadas_ticket_trim_chk'
  ) then
    alter table public.pesadas
      add constraint pesadas_ticket_trim_chk
      check (ticket = btrim(ticket) and length(ticket) > 0);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'pesadas_proveedor_format_chk'
  ) then
    alter table public.pesadas
      add constraint pesadas_proveedor_format_chk
      check (
        proveedor = btrim(proveedor)
        and proveedor = upper(proveedor)
        and proveedor ~ '^[A-Z0-9]+( [A-Z0-9]+)*$'
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'pesadas_precio_nonnegative_chk'
  ) then
    alter table public.pesadas
      add constraint pesadas_precio_nonnegative_chk
      check (precio >= 0);
  end if;
end
$$;

create or replace function public.set_pesadas_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_set_pesadas_updated_at on public.pesadas;
create trigger trg_set_pesadas_updated_at
before update on public.pesadas
for each row
execute function public.set_pesadas_updated_at();

alter table public.pesadas enable row level security;
grant select, insert, update, delete on public.pesadas to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'pesadas'
      and policyname = 'pesadas_authenticated_all'
  ) then
    create policy pesadas_authenticated_all
      on public.pesadas
      for all
      to authenticated
      using (true)
      with check (true);
  end if;
end
$$;

commit;
