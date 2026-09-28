# Corrección de rentabilidad operativa — 22/09/2026

La lectura anterior no sustentaba la conclusión de que la mayoría de las cuentas no aporta. El modelo corregido distingue contribución de atención y carga del soporte compartido; conserva importes negativos y supuestos visibles.

Periodo comparado: **01–22/09/2026**. Lecturas: 2026-09-22T14:20:05.471975 y 2026-09-22T14:32:18.890547. Las fuentes permanecen activas: entre ambas se agregó un ticket de Menudeo, una venta Mayoreo y una factura. El antes/después incluye esos registros; no es una simulación de fuentes congeladas.

| Indicador | Anterior | Corregido |
|---|---:|---:|
| Cuentas | 70 | 74 |
| Genera | $2,519,717.73 | $4,083,985.80 |
| Cuesta | $4,489,018.35 | $4,074,671.09 |
| Aporte con soporte | −$1,969,300.62 | $9,314.72 |
| Cuentas positivas después del soporte | 6 | 19 |

**66 de 74 cuentas aportan antes del soporte compartido.** Su aporte agregado es $1,314,883.92, frente a $1,305,569.20 de soporte asignado. Una cuenta que aporta antes del reparto no necesariamente deja dinero después de sostener la estructura, pero el costo compartido tampoco necesariamente desaparece al retirarla.

## Correcciones verificadas

- Cartón americano → Cartón Celanese, confirmado por Dirección. Precio ponderado de ventas del corte/comparable disponible.
- Familias según catálogos: Ordinario de primera sí entra a CARTON; ACERO clasificado METAL no se mezcla con chatarra. Fallback por promedio ponderado de ventas, no por el SKU más barato.
- Integración de entradas físicas con compras. Enlaces únicos por folio/material/kg trasladan costo y valor juntos. Sin enlace, máximo de cantidades por planta/familia, no suma.
- $837,557.39 de financiamiento y $48,102.00 de gastos personales quedan fuera del aporte. La conciliación también muestra $217,944.80 de tesorería; parte ya estaba excluida en el modelo previo, por lo que no debe atribuirse todo como ahorro nuevo.
- Aporte antes y después del soporte, con textos que distinguen pérdidas de atención y efecto del reparto.

## Ejemplos por empresa

| Cuenta | Genera anterior | Genera corregido | Aporte corregido antes de soporte | Aporte corregido con soporte |
|---|---:|---:|---:|---:|
| ANTONIO MORALES | $293,122.22 | $461,466.92 | $168,973.32 | $151,330.50 |
| MONROE | $131,102.05 | $323,510.49 | $8,179.02 | $-9,463.81 |
| MONROE SUR | $0.00 | $262,825.40 | $92,730.25 | $75,087.42 |
| KS | $10,055.89 | $151,191.96 | $-7,598.57 | $-25,241.40 |
| KEYPACK | $0.00 | $65,208.83 | $10,367.24 | $-7,275.59 |
| MALHE | $0.00 | $88,918.61 | $15,028.95 | $-2,613.87 |

## Límites materiales de la lectura

El ajuste por diferencias de entradas aporta **$1,107,017.47 de valor recuperable estimado y $522,517.18 de compra estimada**. Hay respaldo físico, pero no conciliación individual completa con facturas/pagos. No son ventas realizadas adicionales. El máximo por planta/familia puede cambiar cuando se corrijan fechas, origen o la relación entre planta y proveedor.

La recuperación sigue siendo 100% sin merma capturada; algunas ventas comparables son históricas y la mezcla por familia es una estimación. Hay costos documentales MONROE de 2025. El soporte se distribuye por cuentas atendidas; no existe una clasificación uniforme de puestos que separe todo patio de administración. Los costos adicionales de uso de equipo no se infieren de la amortización de capital de un préstamo. El resultado total cercano a cero es sensible a estas bases y no confirma una utilidad de $9 mil.

## Verificación y trazabilidad

53 pruebas automáticas; análisis estático sin incidencias; compilación macOS correcta; validación SQL de permisos, revisiones e inmutabilidad. Migración 20260922040000 aplicada sola. Corte corregido del piloto 11–17/09 guardado y releído: `d6d35e4b-4fab-4eff-9be6-d992872f72dc`. Los tres cortes previos se conservaron sin cambios.

Comparativo completo: [CSV por empresa](../../../../work/rentabilidad_empresas_20260921/comparacion_corregida_20260901_22.csv). Resumen y referencias: [JSON](../../../../work/rentabilidad_empresas_20260921/comparacion_corregida_20260901_22.json).
