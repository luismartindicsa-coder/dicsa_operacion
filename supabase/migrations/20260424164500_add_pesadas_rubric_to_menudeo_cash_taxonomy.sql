begin;

with pesadas_rubric as (
  select jsonb_build_object(
    'movement_type', 'deposit',
    'label', 'Pesadas',
    'concepts', jsonb_build_array(
      jsonb_build_object(
        'id', 'dep-scale-income',
        'label', 'Ingreso',
        'requires_unit', false,
        'requires_quantity', false,
        'requires_company', false,
        'requires_driver', false,
        'requires_destination', false,
        'requires_subconcept', false,
        'requires_mode', false,
        'subconcepts', jsonb_build_array(),
        'modes', jsonb_build_array(),
        'company_options', jsonb_build_array(),
        'driver_options', jsonb_build_array(),
        'destination_options', jsonb_build_array(),
        'company_is_text', false,
        'subconcept_is_text', false,
        'quantity_label', 'Cantidad',
        'amount_label', 'Importe',
        'company_label', 'Empresa',
        'subconcept_label', 'Subconcepto',
        'comment_label', 'Comentario corto'
      )
    )
  ) as rubric
),
updated as (
  update public.cash_taxonomy_configs c
  set payload = case
    when exists (
      select 1
      from jsonb_array_elements(coalesce(c.payload->'rubrics', '[]'::jsonb)) as rubric
      where rubric->>'movement_type' = 'deposit'
        and rubric->>'label' = 'Pesadas'
    ) then coalesce(c.payload, '{}'::jsonb)
    else jsonb_set(
      coalesce(c.payload, '{}'::jsonb),
      '{rubrics}',
      coalesce(c.payload->'rubrics', '[]'::jsonb) || (select jsonb_build_array(rubric) from pesadas_rubric),
      true
    )
  end
  where c.area = 'menudeo'
  returning 1
)
insert into public.cash_taxonomy_configs (area, payload)
select
  'menudeo',
  jsonb_build_object(
    'rubrics',
    jsonb_build_array((select rubric from pesadas_rubric))
  )
where not exists (select 1 from updated);

commit;
