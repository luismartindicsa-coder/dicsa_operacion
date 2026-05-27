begin;

grant insert on public.compras_price_adjustment_history to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'compras_price_adjustment_history'
      and policyname = 'compras_price_adjustment_history_authenticated_insert'
  ) then
    create policy compras_price_adjustment_history_authenticated_insert
      on public.compras_price_adjustment_history
      for insert
      to authenticated
      with check (true);
  end if;
end
$$;

commit;
