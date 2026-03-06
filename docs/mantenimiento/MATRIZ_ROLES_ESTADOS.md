# Matriz Roles-Estados (Fuente Unica)

## Roles funcionales
- Operador
- Jefe Area / Control Transporte / Encargado Fabricas
- Jefe Operativo
- Auxiliar Direccion
- Finanzas
- Mensajeria
- Tecnico/Mecanico
- Admin (override)

## Transiciones permitidas
- `AVISO_FALLA -> REVISION_AREA`: Jefe Area / Control Transporte / Encargado Fabricas
- `REVISION_AREA -> REPORTE_MANTENIMIENTO`: Jefe Operativo
- `REPORTE_MANTENIMIENTO -> COTIZACION`: Auxiliar Direccion
- `COTIZACION -> AUTORIZACION_FINANZAS`: Finanzas
- `AUTORIZACION_FINANZAS -> MATERIAL_RECOLECTADO`: Mensajeria
- `MATERIAL_RECOLECTADO -> PROGRAMADO`: Auxiliar Direccion
- `PROGRAMADO -> MANTENIMIENTO_REALIZADO`: Tecnico/Mecanico
- `MANTENIMIENTO_REALIZADO -> SUPERVISION`: Jefe Area
- `SUPERVISION -> CERRADO`: Jefe Operativo
- `* -> RECHAZADO`: Responsable del paso actual (comentario obligatorio)

## Reglas de validacion minima
- No pasar a `MANTENIMIENTO_REALIZADO` sin diagnostico y al menos una actividad.
- No cerrar sin al menos una evidencia categoria `despues`.
- Solo Jefe Operativo o Admin puede cerrar.
