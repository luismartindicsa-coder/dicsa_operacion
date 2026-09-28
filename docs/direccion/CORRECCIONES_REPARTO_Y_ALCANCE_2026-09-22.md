# Correcciones de reparto y alcance — 22/09/2026

Implementación posterior a la auditoría crítica, autorizada por Dirección con excepción del punto 6 de la respuesta: valoración/rendimientos del material y compra inferida. `profitability_material_basis.dart` y el bloque de valoración automática conservan exactamente el contenido previo. Los alias confirmados y el alcance visible pueden cambiar agrupaciones y subtotales sin modificar esas fórmulas.

## Decisiones confirmadas

- Incluir todos los centros: Celaya, Apaseo, Mazatlán y VH.
- SETEX = SETEXMES; BOSCH/BOCHS = DESPERDICIOS QUERETANA BOSCH. El nombre visible proviene de Compras Mayoreo. No se fusionan plantas ambiguas.
- Mostrar las empresas de Compras Mayoreo y sus plantas vinculadas; otras actividades conservan su participación en el reparto.
- Mauricio Alcalá y Mónica Chávez son compras de material ya incluidas en tickets, aunque con otro nombre. Sus facturas se muestran en conciliación sin sumarlas como otros gastos. No existe enlace individual comprobado factura-ticket; la base de exclusión es la confirmación de Dirección del 22/09/2026.
- Maricruz Quiroga Acosta: la interpretación inicial como gasto común se corrigió. Su concepto está pendiente de conciliar con la clasificación de Finanzas; se conserva cuantificado en el resultado global, sin reparto a empresas. Ver `CONCILIACION_INCREMENTO_COSTOS_2026-09-22.md`.

## Cambios

1. Combustible por unidad/día, con respaldo de actividad de la misma unidad en el corte. Kilómetros de otra unidad no alteran su reparto. Viajes no cubiertos mantienen estimación propia; cargas sin actividad atribuible permanecen cuantificadas fuera de cuentas.
2. Nómina de choferes por viajes/km; patio/soporte sin puesto identificado por kg/movimientos. Se usa el máximo diario entre fuentes de movimientos para evitar sumar la misma actividad varias veces. Sin actividad, la capacidad permanece fuera de las cuentas y se resta al resultado de toda la operación modelada.
3. IMSS/cargas laborales según remuneración RH y su proporción dedicada/compartida. Administración por movimientos, otros por participaciones en kg/movimientos, capacitación por RH. Se elimina el reparto igualitario automático.
4. Consumo según cobertura explícita del documento; mensualidades por días del mes correspondiente. Finanzas consulta documentos posteriores al subperiodo dentro del mismo mes y disponibles a la fecha de consulta.
5. Factura manual completa frente a pagos parciales/totales: consumo y liquidación ya no se sustituyen ni suman. Se conservan los vínculos OT/compra. Compras para almacén sin OT quedan como inventario pendiente de consumo.
6. Referencias históricas como complemento residual: se descuenta el consumo actual comparable y se respeta cobertura explícita. Mantenimiento agrupa por centro/empresa/equipo sin crear una reserva distinta por taller. Extraordinarios y otros/administración sin recurrencia identificable no se proyectan como gastos nuevos; se conserva evidencia de lo no aplicado.
7. Facturar un servicio no elimina el ingreso estimado del resto. Parámetros de ingreso, incluso cero, cubren únicamente su vigencia.
8. Pantalla, consolidado, selección, CSV y snapshot usan el alcance de Compras. Conciliación muestra otras actividades, costos sin actividad, almacén y facturas de material cubiertas por tickets. El simulador presenta además el resultado de toda la operación modelada.

## Lectura anterior de control (previa a la corrección residual)

Periodo 01–22/09/2026; lectura `2026-09-22T17:03:33.091691`. Consulta autenticada de solo lectura, sin cambiar operaciones ni guardar nuevos cortes. Las fuentes siguen activas; no comparar su variación con lecturas anteriores como efecto exclusivo del código.

| Medida | Lectura |
|---|---:|
| Empresas/plantas con actividad visibles | 19 |
| Otras actividades conservadas fuera del catálogo | 55 |
| Genera del alcance visible | $2,466,859.96 |
| Costos del alcance visible | $2,808,490.43 |
| Aporte del alcance visible | $-341,630.47 |
| Costos sin actividad atribuible, fuera de cuentas | $26,811.80 |
| Facturas de material ya cubiertas por tickets | $171,383.44 |
| Resultado de todas las actividades modeladas | $-816,239.40 |

El resultado es una estimación operativa, no una certificación de utilidad. Permanece la incertidumbre de recuperación/precios del punto excluido, funciones de RH no capturadas, referencias MONROE antiguas y conciliaciones sin enlace individual. Las pruebas comprueban aritmética, cobertura, conservación y reglas; no prueban que las proporciones representen horas reales.

## Verificación

- Suite de 105 pruebas aprobada antes de la última confirmación; tras añadir la conciliación, 49 pruebas de las cinco superficies afectadas aprobadas, incluida la nueva prueba (106 casos únicos en el conjunto).
- Análisis estático sin incidencias; prueba real de conciliación y tamaño del snapshot aprobada. Evidencia temporal: `/private/tmp/dicsa_profit_reconciled_final.json`.
- Snapshot de esta lectura: 15,839,766 bytes; debajo del límite de 20 MB. Evidencia histórica agrupada una vez, referenciada desde componentes.
- Control visual con widgets a 1440 y 760 px; pruebas de exportación y PDF aprobadas. Compilación macOS debug verificada.
- No se ejecutaron migraciones ni se modificaron registros de origen. Los cortes guardados anteriores permanecen inmutables.
