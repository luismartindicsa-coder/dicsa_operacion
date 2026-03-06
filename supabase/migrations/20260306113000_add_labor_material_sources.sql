do $$
begin
  alter type public.material_source add value if not exists 'mano_obra';
  alter type public.material_source add value if not exists 'servicio_tecnico';
end $$;

