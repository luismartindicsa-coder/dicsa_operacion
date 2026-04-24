begin;

update public.cash_taxonomy_configs
set payload = jsonb_set(
  coalesce(payload, '{}'::jsonb),
  '{rubrics}',
  jsonb_build_array(
    jsonb_build_object(
      'movement_type', 'deposit',
      'label', 'Venta de material',
      'concepts', jsonb_build_array(
        jsonb_build_object('id', 'dep-sale-income', 'label', 'Ingreso')
      )
    ),
    jsonb_build_object(
      'movement_type', 'deposit',
      'label', 'Reposicion de fondo',
      'concepts', jsonb_build_array(
        jsonb_build_object('id', 'dep-repo-vault', 'label', 'Boveda'),
        jsonb_build_object('id', 'dep-repo-big-cash', 'label', 'Caja grande')
      )
    ),
    jsonb_build_object(
      'movement_type', 'deposit',
      'label', 'Servicio de transporte',
      'concepts', jsonb_build_array(
        jsonb_build_object('id', 'dep-transport-buy', 'label', 'Compra de material'),
        jsonb_build_object('id', 'dep-transport-sell', 'label', 'Venta de material')
      )
    ),
    jsonb_build_object(
      'movement_type', 'deposit',
      'label', 'Pesadas',
      'concepts', jsonb_build_array(
        jsonb_build_object('id', 'dep-scale-income', 'label', 'Ingreso')
      )
    ),
    jsonb_build_object(
      'movement_type', 'expense',
      'label', 'Operativo',
      'concepts', jsonb_build_array(
        jsonb_build_object(
          'id', 'exp-op-fuel',
          'label', 'Combustible',
          'requires_unit', true,
          'requires_quantity', true
        ),
        jsonb_build_object(
          'id', 'exp-op-maintenance',
          'label', 'Mantenimiento',
          'requires_unit', true,
          'requires_subconcept', true,
          'subconcepts', jsonb_build_array(
            'Talacha','Luz','Espejos','Llantas','Mangueras','Electricidad','Mecanica'
          )
        ),
        jsonb_build_object(
          'id', 'exp-op-commissions',
          'label', 'Comisiones'
        ),
        jsonb_build_object(
          'id', 'exp-op-scale',
          'label', 'Bascula',
          'requires_company', true,
          'requires_driver', true
        ),
        jsonb_build_object(
          'id', 'exp-op-gratification',
          'label', 'Gratificacion',
          'requires_driver', true,
          'requires_destination', true,
          'destination_options', jsonb_build_array(
            'De Acero','Grupak','San Pablo','San Luis','Jaime Velazquez','TDF','Morelia','Queretaro','Queretania'
          )
        ),
        jsonb_build_object(
          'id', 'exp-op-dinner',
          'label', 'Cena',
          'requires_driver', true,
          'requires_destination', true,
          'destination_options', jsonb_build_array(
            'De Acero','Grupak','San Pablo','San Luis','Jaime Velazquez','TDF','Morelia','Queretaro','Queretania'
          )
        ),
        jsonb_build_object(
          'id', 'exp-op-equipment',
          'label', 'Equipo',
          'requires_subconcept', true,
          'requires_quantity', true,
          'subconcepts', jsonb_build_array(
            'Guantes','Lentes','Chalecos','Tapones','Uniformes','Zapatos','Extintores','Cables','Almacen','Tanques','Agujas'
          )
        ),
        jsonb_build_object(
          'id', 'exp-op-freight',
          'label', 'Flete',
          'requires_destination', true,
          'destination_options', jsonb_build_array(
            'De Acero','Grupak','San Pablo','San Luis','Jaime Velazquez','TDF','Morelia','Queretaro','Queretania'
          ),
          'requires_mode', true,
          'modes', jsonb_build_array('Full', 'Sencillo')
        ),
        jsonb_build_object(
          'id', 'exp-op-trips',
          'label', 'Viajes',
          'requires_subconcept', true,
          'subconcepts', jsonb_build_array(
            'Comida','Caseta','Combustible','Estacionamiento','Transito'
          )
        ),
        jsonb_build_object(
          'id', 'exp-op-oxygen',
          'label', 'Oxigeno',
          'requires_quantity', true
        )
      )
    ),
    jsonb_build_object(
      'movement_type', 'expense',
      'label', 'Administrativo',
      'concepts', jsonb_build_array(
        jsonb_build_object(
          'id', 'exp-admin-stationery',
          'label', 'Papeleria',
          'requires_subconcept', true,
          'requires_quantity', true,
          'subconcepts', jsonb_build_array(
            'Plumas','Lapices','Plumones','Borradores','Post-its','Hojas','Pegamento','Tijeras','Calculadora','USB','Engrapadora','Grapas','Sobres'
          )
        ),
        jsonb_build_object(
          'id', 'exp-admin-maintenance',
          'label', 'Mantenimiento',
          'requires_subconcept', true,
          'subconcepts', jsonb_build_array(
            'Impresoras','Computadoras','Telefonos','Oficina'
          )
        ),
        jsonb_build_object(
          'id', 'exp-admin-remodel',
          'label', 'Remodelacion'
        )
      )
    ),
    jsonb_build_object(
      'movement_type', 'expense',
      'label', 'Nomina',
      'concepts', jsonb_build_array(
        jsonb_build_object(
          'id', 'exp-payroll-company',
          'label', 'Empresa',
          'requires_subconcept', true,
          'subconcepts', jsonb_build_array('Whirlpool', 'KS', 'Monroe')
        ),
        jsonb_build_object('id', 'exp-payroll-loan', 'label', 'Prestamo')
      )
    ),
    jsonb_build_object(
      'movement_type', 'expense',
      'label', 'Personales',
      'concepts', jsonb_build_array(
        jsonb_build_object('id', 'exp-personal-food', 'label', 'Comida'),
        jsonb_build_object('id', 'exp-personal-gas', 'label', 'Gasolina'),
        jsonb_build_object('id', 'exp-personal-tolls', 'label', 'Casetas')
      )
    )
  ),
  true
)
where area = 'menudeo';

insert into public.cash_taxonomy_configs (area, payload)
select
  'menudeo',
  jsonb_build_object(
    'rubrics',
    jsonb_build_array(
      jsonb_build_object(
        'movement_type', 'deposit',
        'label', 'Venta de material',
        'concepts', jsonb_build_array(
          jsonb_build_object('id', 'dep-sale-income', 'label', 'Ingreso')
        )
      ),
      jsonb_build_object(
        'movement_type', 'deposit',
        'label', 'Reposicion de fondo',
        'concepts', jsonb_build_array(
          jsonb_build_object('id', 'dep-repo-vault', 'label', 'Boveda'),
          jsonb_build_object('id', 'dep-repo-big-cash', 'label', 'Caja grande')
        )
      ),
      jsonb_build_object(
        'movement_type', 'deposit',
        'label', 'Servicio de transporte',
        'concepts', jsonb_build_array(
          jsonb_build_object('id', 'dep-transport-buy', 'label', 'Compra de material'),
          jsonb_build_object('id', 'dep-transport-sell', 'label', 'Venta de material')
        )
      ),
      jsonb_build_object(
        'movement_type', 'deposit',
        'label', 'Pesadas',
        'concepts', jsonb_build_array(
          jsonb_build_object('id', 'dep-scale-income', 'label', 'Ingreso')
        )
      ),
      jsonb_build_object(
        'movement_type', 'expense',
        'label', 'Operativo',
        'concepts', jsonb_build_array(
          jsonb_build_object(
            'id', 'exp-op-fuel',
            'label', 'Combustible',
            'requires_unit', true,
            'requires_quantity', true
          ),
          jsonb_build_object(
            'id', 'exp-op-maintenance',
            'label', 'Mantenimiento',
            'requires_unit', true,
            'requires_subconcept', true,
            'subconcepts', jsonb_build_array(
              'Talacha','Luz','Espejos','Llantas','Mangueras','Electricidad','Mecanica'
            )
          ),
          jsonb_build_object('id', 'exp-op-commissions', 'label', 'Comisiones'),
          jsonb_build_object(
            'id', 'exp-op-scale',
            'label', 'Bascula',
            'requires_company', true,
            'requires_driver', true
          ),
          jsonb_build_object(
            'id', 'exp-op-gratification',
            'label', 'Gratificacion',
            'requires_driver', true,
            'requires_destination', true,
            'destination_options', jsonb_build_array(
              'De Acero','Grupak','San Pablo','San Luis','Jaime Velazquez','TDF','Morelia','Queretaro','Queretania'
            )
          ),
          jsonb_build_object(
            'id', 'exp-op-dinner',
            'label', 'Cena',
            'requires_driver', true,
            'requires_destination', true,
            'destination_options', jsonb_build_array(
              'De Acero','Grupak','San Pablo','San Luis','Jaime Velazquez','TDF','Morelia','Queretaro','Queretania'
            )
          ),
          jsonb_build_object(
            'id', 'exp-op-equipment',
            'label', 'Equipo',
            'requires_subconcept', true,
            'requires_quantity', true,
            'subconcepts', jsonb_build_array(
              'Guantes','Lentes','Chalecos','Tapones','Uniformes','Zapatos','Extintores','Cables','Almacen','Tanques','Agujas'
            )
          ),
          jsonb_build_object(
            'id', 'exp-op-freight',
            'label', 'Flete',
            'requires_destination', true,
            'destination_options', jsonb_build_array(
              'De Acero','Grupak','San Pablo','San Luis','Jaime Velazquez','TDF','Morelia','Queretaro','Queretania'
            ),
            'requires_mode', true,
            'modes', jsonb_build_array('Full', 'Sencillo')
          ),
          jsonb_build_object(
            'id', 'exp-op-trips',
            'label', 'Viajes',
            'requires_subconcept', true,
            'subconcepts', jsonb_build_array(
              'Comida','Caseta','Combustible','Estacionamiento','Transito'
            )
          ),
          jsonb_build_object(
            'id', 'exp-op-oxygen',
            'label', 'Oxigeno',
            'requires_quantity', true
          )
        )
      ),
      jsonb_build_object(
        'movement_type', 'expense',
        'label', 'Administrativo',
        'concepts', jsonb_build_array(
          jsonb_build_object(
            'id', 'exp-admin-stationery',
            'label', 'Papeleria',
            'requires_subconcept', true,
            'requires_quantity', true,
            'subconcepts', jsonb_build_array(
              'Plumas','Lapices','Plumones','Borradores','Post-its','Hojas','Pegamento','Tijeras','Calculadora','USB','Engrapadora','Grapas','Sobres'
            )
          ),
          jsonb_build_object(
            'id', 'exp-admin-maintenance',
            'label', 'Mantenimiento',
            'requires_subconcept', true,
            'subconcepts', jsonb_build_array(
              'Impresoras','Computadoras','Telefonos','Oficina'
            )
          ),
          jsonb_build_object('id', 'exp-admin-remodel', 'label', 'Remodelacion')
        )
      ),
      jsonb_build_object(
        'movement_type', 'expense',
        'label', 'Nomina',
        'concepts', jsonb_build_array(
          jsonb_build_object(
            'id', 'exp-payroll-company',
            'label', 'Empresa',
            'requires_subconcept', true,
            'subconcepts', jsonb_build_array('Whirlpool', 'KS', 'Monroe')
          ),
          jsonb_build_object('id', 'exp-payroll-loan', 'label', 'Prestamo')
        )
      ),
      jsonb_build_object(
        'movement_type', 'expense',
        'label', 'Personales',
        'concepts', jsonb_build_array(
          jsonb_build_object('id', 'exp-personal-food', 'label', 'Comida'),
          jsonb_build_object('id', 'exp-personal-gas', 'label', 'Gasolina'),
          jsonb_build_object('id', 'exp-personal-tolls', 'label', 'Casetas')
        )
      )
    )
  )
where not exists (
  select 1 from public.cash_taxonomy_configs where area = 'menudeo'
);

commit;
