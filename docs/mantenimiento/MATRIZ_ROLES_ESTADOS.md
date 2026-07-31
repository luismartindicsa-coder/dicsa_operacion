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
- `AVISO_FALLA -> COTIZACION`: Jefe Area / Control Transporte / Encargado Fabricas / Jefe Operativo / Auxiliar Direccion
- `COTIZACION -> AUTORIZACION_FINANZAS`: Finanzas
- `AUTORIZACION_FINANZAS -> SUPERVISION`: Tecnico / Mecanico / Services / Jefe Area / Control Transporte
- `SUPERVISION -> CERRADO`: Jefe Operativo
- `RECHAZADO -> AVISO_FALLA | COTIZACION | AUTORIZACION_FINANZAS`: Correccion segun el caso
- `* -> RECHAZADO`: Responsable del paso actual (comentario obligatorio)

## Flujo visible en Operaciones
- `AVISO_FALLA`: agrupa `AVISO_FALLA`, `REVISION_AREA` y `REPORTE_MANTENIMIENTO`.
- `COTIZACION`: se mantiene como etapa operativa dedicada.
- `AUTORIZACION_FINANZAS`: agrupa autorizacion y preparacion operativa previa a supervision.
- `SUPERVISION`: agrupa ejecucion concluida y validacion final.
- `CERRADO`: cierre formal de la OT.

## Reglas de validacion minima
- No pasar a `SUPERVISION` sin diagnostico y al menos una actividad.
- No cerrar sin al menos una evidencia categoria `despues`.
- Solo Jefe Operativo o Admin puede cerrar.
