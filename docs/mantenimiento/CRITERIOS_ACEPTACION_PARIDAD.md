# Criterios de Aceptacion: Paridad Operativa

## Regla base
Toda interaccion tipo grid/tabla de Mantenimiento debe replicar la base de Entradas/Salidas antes de personalizar campos.

## Checklist obligatorio
- [ ] Click simple permite escribir al primer click en celdas/campos editables.
- [ ] `Enter` guarda/avanza segun patron operativo.
- [ ] `Esc` cancela sin perder consistencia de seleccion.
- [ ] `Delete/Backspace` borra texto en inputs editables; no dispara borrado de fila accidental.
- [ ] Seleccion simple/multiple por mouse/teclado consistente.
- [ ] Hover, fila activa y estados seleccionados con misma paleta operativa.
- [ ] Recarga diferida/silenciosa sin romper captura activa.
- [ ] Dialogos y filtros alineados visualmente al estandar operativo.

## Definition of Done del modulo
- Flujo manual completo funcional de `AVISO_FALLA` a `CERRADO`.
- Evidencias visibles y capturables desde tabla y detalle.
- Trazabilidad de cambios de estado en `maintenance_status_log`.
- `dart format` y `dart analyze` sin errores.
