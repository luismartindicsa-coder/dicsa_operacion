do $$
begin
  alter type public.approval_step add value if not exists 'operador';
  alter type public.approval_step add value if not exists 'jefe_area';
  alter type public.approval_step add value if not exists 'interviniente';
  alter type public.approval_step add value if not exists 'jefe_operativo';
  alter type public.approval_step add value if not exists 'finanzas';
end $$;

