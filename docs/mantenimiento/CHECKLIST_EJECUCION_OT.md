# Checklist de Ejecucion OT

## Estado de tareas
- `pendiente`
- `en_progreso`
- `completado`

## Fase 1: Base tecnica
- [x] (completado) Crear carpeta de plan maestro en `docs/mantenimiento`.
- [x] (completado) Definir flujo oficial y alcance MVP.
- [x] (completado) Crear migracion de mantenimiento en Supabase.
- [x] (completado) Definir RLS/policies para tablas y storage.
- [x] (completado) Ejecutar migracion en entorno destino.

## Fase 2: Lista OT
- [x] (completado) Crear pagina de mantenimiento con tabla de resumen.
- [x] (completado) Agregar filtros por estado, prioridad y busqueda.
- [x] (completado) Agregar columna `📷 Evidencias` con contador.
- [x] (completado) Abrir drawer/modal de evidencias desde tabla.

## Fase 3: Hoja digital
- [x] (completado) Formulario unico con secciones verticales.
- [x] (completado) CRUD de actividades.
- [x] (completado) CRUD de materiales.
- [x] (completado) Extender materiales para incluir mano de obra/servicio tecnico como fuente de costo.
- [x] (completado) CRUD de tiempos.
- [x] (completado) CRUD de aprobaciones.

## Fase 4: Workflow
- [x] (completado) Boton de cambio de estado con transiciones validas por rol.
- [x] (completado) Bloquear cierre sin diagnostico.
- [x] (completado) Bloquear cierre sin actividades.
- [x] (completado) Bloquear cierre sin evidencia `despues`.
- [x] (completado) Guardar auditoria en `maintenance_status_log`.

## Fase 5: QA
- [ ] (pendiente) Verificar paridad UX base con Entradas/Salidas.
- [x] (completado) Ejecutar `dart format`.
- [x] (completado) Ejecutar `dart analyze` (sin errores nuevos; warnings existentes del repo).
- [ ] (pendiente) Ajustes finales de usabilidad.
