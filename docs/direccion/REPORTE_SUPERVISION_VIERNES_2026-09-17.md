# Dirección General · Resumen de todas las áreas

Implementación local del 17 de septiembre de 2026. El PDF de viernes deja de ser un catálogo de reportes y consulta las bases operativas de toda la app. Disponible mediante el generador central de Supervisión y el botón existente del dashboard de Dirección.

## Cobertura

La lista incluye áreas del menú de Dirección, áreas de Supervisión y módulos operativos con indicadores propios. Catálogos y directorios se consideran parte del área que los utiliza; no se presentan como resultados económicos independientes.

| Bloque | Base e indicadores principales |
| --- | --- |
| Operación y Producción | Análisis semanal existente: transformaciones V2, pacas históricas cuando corresponde, OT y compras ligadas. Kg, unidades y pendientes de mantenimiento. |
| Báscula | Mismo análisis del PDF de Báscula: entradas, salidas, pesadas y problemas de captura. |
| Inventario | Vistas `v_inventory_general_balance_v2` y `v_inventory_commercial_balance_v2`; niveles separados, saldos negativos. |
| Almacén | `inventory_items`: artículos activos, mínimos y faltantes. |
| Logística | Mismo análisis de servicios, diésel y gasolina del reporte individual. |
| Embarques | `direction_shipment_plans`: cantidades planeadas marcadas embarcadas, pendientes y cancelados, separando pacas y kg. |
| Menudeo | Mismo análisis de tickets, caja, cortes y ajustes de precios. |
| Compras Mayoreo | `v_commercial_market_events`, origen `mayoreo_compras`: compras, kg, operaciones y precio ponderado. |
| Ventas Mayoreo | Origen `mayoreo_ventas` de la misma vista, más cuentas y cobranza conciliada con bancos. |
| Desarrollo Comercial | Mismo análisis CRM: prospectos, contactos, seguimientos, visitas y alertas. |
| Finanzas | Movimientos bancarios y `finanzas_supplier_invoices`: flujo semanal, saldo abierto actual y vencido. |
| Bóveda | Repositorio de vales actual e histórico sin duplicar identificadores y sin migración. |
| Gastos | Mismo análisis de OC de mantenimiento: importe comprado, pendientes y desviaciones. |
| Contabilidad | Mismo resultado comercial y estado de resultados simplificado que el reporte individual, comparados con la semana anterior. |
| RH | Mismo análisis de plantilla, asistencia, permisos y nómina; periodo seleccionado visible. Sin periodo o sin partidas de nómina: `Sin captura`. |
| Gestión Documental | RPC autorizado y registros de las 11 categorías; fecha empresarial, vencimientos, riesgos y agenda. |
| Gerencia | Plan semanal en modo de lectura, metas y avances. Producción y salidas se consultan con paginación para no truncar semanas grandes. |
| Supervisión | Historial local de hasta 60 generaciones guardadas; cuenta áreas una sola vez y excluye el propio consolidado. |

## Cortes y significado

- El corte comercial/financiero usa fechas de lunes a viernes, o los mismos días disponibles si se genera antes. Los módulos existentes conservan sus reglas de fecha/hora dentro de ese corte. En fin de semana se normaliza la referencia al viernes recién concluido, evitando saltar al lunes siguiente.
- No se reconstruyen saldos históricos: existencias, cuentas abiertas, estados de OT/OC/embarques y expedientes son los vigentes al consultar. El periodo RH y el horizonte de metas se muestran expresamente.
- No se totalizan entre áreas montos de una misma operación. Contabilidad conserva las exclusiones y conciliaciones de su pantalla. Bancos y Bóveda incluyen transferencias y no representan utilidad. Las OC de mantenimiento no se añaden al gasto contable.
- Pacas y kg se mantienen separados. Los niveles de Inventario no se suman entre sí ni sustituyen el conteo físico. El plan de embarques no sustituye pesos certificados de Báscula.
- Catálogo de Supervisión: resumen de todas las áreas, comparativo semanal, metas/alertas y cobertura. Se elimina el antiguo alcance limitado a producción/embarques y avance de desarrollo de software.

## Disponibilidad y límites

Las 18 posiciones siempre aparecen. Un error de consulta no elimina el área ni sustituye datos por cero. El PDF indica `CONSOLIDADO INCOMPLETO` cuando hay bases no disponibles; si solo responde el historial local, se detiene la exportación. Se consultan los datos visibles para el usuario autenticado; no se amplían permisos ni se modifican registros.

Los límites de los indicadores siguen visibles: kilometraje/rendimiento no están resumidos; Ventas no incorpora aún ajustes de precios ni tiempos completos de pago; accidentes/reclutamiento/vacantes, incidencias de patio, subsidios y trazabilidad cuantitativa de manifiestos permanecen pendientes. Reservas, convenios y programación financiera conservan su detalle en Finanzas. Esto no impide incluir el resumen existente de cada área.

El historial local no acredita entrega, aprobación ni cumplimiento de reportes en otros dispositivos. Las alertas se resumen con dos avisos por bloque y el conteo de adicionales; el detalle permanece en el reporte o módulo del área.

## Validación

- Pruebas de cobertura, aislamiento por origen comercial, cortes equivalentes y fin de semana, unidades de embarque, almacén, inventario, importes faltantes e historial local.
- Prueba integrada de las 18 áreas con HTTP simulado y consultas reales del código; solo GET y el RPC documental de lectura. Paginación por encima de 500 filas y fallos de banco o de todas las fuentes.
- Generación y revisión visual de PDFs normal, vacío, incompleto y con textos/alertas extensos. Datos de prueba fuera del repositorio en `/private/tmp/dicsa_direction_qa`.
- No requiere migración SQL ni se despliega automáticamente.
