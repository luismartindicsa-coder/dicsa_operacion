begin;

-- Ensure lowercase enum values exist for compatibility with app payloads.
do $$
begin
  alter type public.maintenance_status add value if not exists 'aviso_falla';
  alter type public.maintenance_status add value if not exists 'revision_area';
  alter type public.maintenance_status add value if not exists 'reporte_mantenimiento';
  alter type public.maintenance_status add value if not exists 'cotizacion';
  alter type public.maintenance_status add value if not exists 'autorizacion_finanzas';
  alter type public.maintenance_status add value if not exists 'material_recolectado';
  alter type public.maintenance_status add value if not exists 'programado';
  alter type public.maintenance_status add value if not exists 'mantenimiento_realizado';
  alter type public.maintenance_status add value if not exists 'supervision';
  alter type public.maintenance_status add value if not exists 'cerrado';
  alter type public.maintenance_status add value if not exists 'rechazado';

  alter type public.maintenance_priority add value if not exists 'alta';
  alter type public.maintenance_priority add value if not exists 'media';
  alter type public.maintenance_priority add value if not exists 'baja';

  alter type public.maintenance_type add value if not exists 'preventivo';
  alter type public.maintenance_type add value if not exists 'correctivo';
  alter type public.maintenance_type add value if not exists 'mejora';

  alter type public.maintenance_category add value if not exists 'mecanica';
  alter type public.maintenance_category add value if not exists 'electrica';
  alter type public.maintenance_category add value if not exists 'hidraulica';
  alter type public.maintenance_category add value if not exists 'neumatica';
  alter type public.maintenance_category add value if not exists 'electronica';
  alter type public.maintenance_category add value if not exists 'otros';

  alter type public.maintenance_impact add value if not exists 'paro_total';
  alter type public.maintenance_impact add value if not exists 'paro_parcial';
  alter type public.maintenance_impact add value if not exists 'sin_impacto';

  alter type public.provider_type add value if not exists 'interno';
  alter type public.provider_type add value if not exists 'externo';

  alter type public.material_source add value if not exists 'almacen';
  alter type public.material_source add value if not exists 'compra';
  alter type public.material_source add value if not exists 'proveedor';

  alter type public.evidence_category add value if not exists 'antes';
  alter type public.evidence_category add value if not exists 'durante';
  alter type public.evidence_category add value if not exists 'despues';
  alter type public.evidence_category add value if not exists 'facturas';
  alter type public.evidence_category add value if not exists 'otros';

  alter type public.approval_step add value if not exists 'area';
  alter type public.approval_step add value if not exists 'mantenimiento';
  alter type public.approval_step add value if not exists 'verificacion';
  alter type public.approval_step add value if not exists 'direccion';

  alter type public.approval_status add value if not exists 'pendiente';
  alter type public.approval_status add value if not exists 'aprobada';
  alter type public.approval_status add value if not exists 'rechazada';
exception
  when undefined_object then
    -- Some projects may not have all enum types yet.
    null;
end
$$;

commit;

begin;

-- Normalize legacy uppercase enum rows to lowercase canonical values.
update public.maintenance_orders
set status = 'aviso_falla'::public.maintenance_status
where status::text = 'AVISO_FALLA';

update public.maintenance_orders
set status = 'revision_area'::public.maintenance_status
where status::text = 'REVISION_AREA';

update public.maintenance_orders
set status = 'reporte_mantenimiento'::public.maintenance_status
where status::text = 'REPORTE_MANTENIMIENTO';

update public.maintenance_orders
set status = 'cotizacion'::public.maintenance_status
where status::text = 'COTIZACION';

update public.maintenance_orders
set status = 'autorizacion_finanzas'::public.maintenance_status
where status::text = 'AUTORIZACION_FINANZAS';

update public.maintenance_orders
set status = 'material_recolectado'::public.maintenance_status
where status::text = 'MATERIAL_RECOLECTADO';

update public.maintenance_orders
set status = 'programado'::public.maintenance_status
where status::text = 'PROGRAMADO';

update public.maintenance_orders
set status = 'mantenimiento_realizado'::public.maintenance_status
where status::text = 'MANTENIMIENTO_REALIZADO';

update public.maintenance_orders
set status = 'supervision'::public.maintenance_status
where status::text = 'SUPERVISION';

update public.maintenance_orders
set status = 'cerrado'::public.maintenance_status
where status::text = 'CERRADO';

update public.maintenance_orders
set status = 'rechazado'::public.maintenance_status
where status::text = 'RECHAZADO';

update public.maintenance_orders
set priority = 'alta'::public.maintenance_priority
where priority::text = 'ALTA';

update public.maintenance_orders
set priority = 'media'::public.maintenance_priority
where priority::text = 'MEDIA';

update public.maintenance_orders
set priority = 'baja'::public.maintenance_priority
where priority::text = 'BAJA';

update public.maintenance_approvals
set status = 'pendiente'::public.approval_status
where status::text = 'PENDIENTE';

update public.maintenance_approvals
set status = 'aprobada'::public.approval_status
where status::text = 'APROBADA';

update public.maintenance_approvals
set status = 'rechazada'::public.approval_status
where status::text = 'RECHAZADA';

commit;
