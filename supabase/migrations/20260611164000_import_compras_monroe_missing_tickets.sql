-- Tickets faltantes de Monroe para Compras Mayoreo.
-- Se insertan solo si no existe ya un ticket con el mismo proveedor, fecha y numero.

begin;

create temporary table tmp_import_compras_monroe_missing_tickets (
  id text,
  ticket_date timestamptz,
  ticket_number text,
  provider_name text,
  material_name text,
  gross_weight numeric(14,3),
  tare_weight numeric(14,3),
  net_weight numeric(14,3),
  humidity_percent numeric(8,3),
  trash_percent numeric(8,3),
  payable_weight numeric(14,3),
  price numeric(14,4),
  premium numeric(14,4),
  amount numeric(14,2),
  factura_status text,
  pago_status text,
  coverage_status text,
  legacy_comentario text
) on commit drop;

insert into tmp_import_compras_monroe_missing_tickets (
  id,
  ticket_date,
  ticket_number,
  provider_name,
  material_name,
  gross_weight,
  tare_weight,
  net_weight,
  humidity_percent,
  trash_percent,
  payable_weight,
  price,
  premium,
  amount,
  factura_status,
  pago_status,
  coverage_status,
  legacy_comentario
) values
  ('ct_monroe_missing_row_2', '2025-08-22T00:00:00Z', '8775', 'MONROE', 'LENA', 5380.000, 5010.000, 370.000, 0.000, 0.000, 370.000, 0.3500, 0.0000, 129.50, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_3', '2025-08-22T00:00:00Z', '8774', 'MONROE', 'LENA', 6740.000, 5380.000, 1360.000, 0.000, 0.000, 1360.000, 0.3500, 0.0000, 476.00, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_4', '2025-08-22T00:00:00Z', '79002', 'MONROE', 'BASURA', 14670.000, 12330.000, 2340.000, 0.000, 0.000, 2340.000, 0.0000, 0.0000, 0.00, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_5', '2025-08-22T00:00:00Z', '8779', 'MONROE', 'CARTON', 14220.000, 12480.000, 1740.000, 0.000, 0.000, 1740.000, 1.4000, 0.0000, 2436.00, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_6', '2025-08-21T00:00:00Z', '8721', 'MONROE', 'LENA', 6330.000, 4900.000, 1430.000, 0.000, 0.000, 1430.000, 0.3500, 0.0000, 500.50, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_7', '2025-08-21T00:00:00Z', '8720', 'MONROE', 'LENA', 6450.000, 4900.000, 1550.000, 0.000, 0.000, 1550.000, 0.3500, 0.0000, 542.50, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_8', '2025-08-21T00:00:00Z', '23421', 'MONROE', 'BASURA', 5320.000, 4890.000, 430.000, 0.000, 0.000, 430.000, 0.0000, 0.0000, 0.00, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_9', '2025-08-21T00:00:00Z', '8688', 'MONROE', 'CARTON', 14230.000, 12540.000, 1690.000, 0.000, 0.000, 1690.000, 1.4000, 0.0000, 2366.00, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_10', '2025-08-21T00:00:00Z', '23424', 'MONROE', 'REBABA', 7450.000, 4650.000, 2800.000, 0.000, 0.000, 2800.000, 2.0300, 0.0000, 5684.00, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_11', '2025-08-21T00:00:00Z', '23423', 'MONROE', 'REBABA', 6170.000, 5010.000, 1160.000, 0.000, 0.000, 1160.000, 2.0300, 0.0000, 2354.80, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_12', '2025-08-21T00:00:00Z', '8726', 'MONROE', 'TARIMAS', 196.000, 0.000, 196.000, 0.000, 0.000, 196.000, 13.0000, 0.0000, 2548.00, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_13', '2025-08-20T00:00:00Z', '8679', 'MONROE', 'LENA', 7100.000, 4850.000, 2250.000, 0.000, 0.000, 2250.000, 0.3500, 0.0000, 787.50, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_14', '2025-08-20T00:00:00Z', '8678', 'MONROE', 'LENA', 6390.000, 4850.000, 1540.000, 0.000, 0.000, 1540.000, 0.3500, 0.0000, 539.00, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_15', '2025-08-20T00:00:00Z', '8677', 'MONROE', 'CARTON', 14060.000, 12540.000, 1520.000, 0.000, 0.000, 1520.000, 1.4000, 0.0000, 2128.00, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_16', '2025-08-19T00:00:00Z', '8630', 'MONROE', 'LENA', 6550.000, 4870.000, 1680.000, 0.000, 0.000, 1680.000, 0.3500, 0.0000, 588.00, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_17', '2025-08-19T00:00:00Z', '69983', 'MONROE', 'BASURA', 14855.000, 12315.000, 2540.000, 0.000, 0.000, 2540.000, 0.0000, 0.0000, 0.00, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_18', '2025-08-19T00:00:00Z', '8601', 'MONROE', 'CARTON', 14300.000, 12500.000, 1800.000, 0.000, 0.000, 1800.000, 1.4000, 0.0000, 2520.00, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_19', '2025-08-19T00:00:00Z', '8631', 'MONROE', 'LENA', 5850.000, 4870.000, 980.000, 0.000, 0.000, 980.000, 0.3500, 0.0000, 343.00, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_20', '2025-08-18T00:00:00Z', '8532', 'MONROE', 'CARTON', 14570.000, 13060.000, 1510.000, 0.000, 0.000, 1510.000, 1.4000, 0.0000, 2114.00, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_21', '2025-08-18T00:00:00Z', '8531', 'MONROE', 'CARTON', 14040.000, 13060.000, 980.000, 0.000, 0.000, 980.000, 1.4000, 0.0000, 1372.00, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_22', '2025-08-18T00:00:00Z', '8589', 'MONROE', 'LENA', 6610.000, 4820.000, 1790.000, 0.000, 0.000, 1790.000, 0.3500, 0.0000, 626.50, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_23', '2025-08-18T00:00:00Z', '8590', 'MONROE', 'LENA', 6410.000, 4820.000, 1590.000, 0.000, 0.000, 1590.000, 0.3500, 0.0000, 556.50, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025'),
  ('ct_monroe_missing_row_24', '2025-08-18T00:00:00Z', '8588', 'MONROE', 'LENA', 6710.000, 4820.000, 1890.000, 0.000, 0.000, 1890.000, 0.3500, 0.0000, 661.50, 'PENDIENTE_DE_FACTURAR', 'PENDIENTE_DE_PAGO', 'SIN_CUBRIR', 'Reporte 18-22 Agosto 2025');

insert into public.compras_tickets (
  id,
  ticket_date,
  ticket_number,
  provider_id,
  provider_name_snapshot,
  material_id,
  material_name_snapshot,
  gross_weight,
  tare_weight,
  net_weight,
  humidity_percent,
  trash_percent,
  payable_weight,
  price,
  premium,
  amount,
  factura_status,
  pago_status,
  coverage_status
)
select
  src.id,
  src.ticket_date,
  src.ticket_number,
  provider.id,
  provider.name,
  material.id,
  material.name,
  src.gross_weight,
  src.tare_weight,
  src.net_weight,
  src.humidity_percent,
  src.trash_percent,
  src.payable_weight,
  src.price,
  src.premium,
  src.amount,
  src.factura_status,
  src.pago_status,
  src.coverage_status
from tmp_import_compras_monroe_missing_tickets src
join public.compras_counterparties provider
  on upper(provider.name) = upper(src.provider_name)
join public.compras_material_catalog material
  on upper(material.name) = upper(src.material_name)
 and material.level = 'COMERCIAL'
where not exists (
  select 1
  from public.compras_tickets existing
  where existing.provider_id = provider.id
    and existing.ticket_date::date = src.ticket_date::date
    and trim(existing.ticket_number) = trim(src.ticket_number)
);

commit;
