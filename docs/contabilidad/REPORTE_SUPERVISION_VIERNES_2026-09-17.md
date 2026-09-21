# Contabilidad: comparativo de viernes

El reporte solicitado contiene dos lecturas: resultado comercial y estado de resultados de la semana contra la anterior. El generador central de Supervisión deja de usar la plantilla genérica para Contabilidad y mantiene el guardado e historial existentes. El dashboard contable enlaza al hub central con el patrón compartido de las otras áreas.

## Periodos

El periodo actual empieza el lunes y termina el día de generación, con límite en viernes. El anterior empieza siete días antes y cubre los mismos días. Antes del viernes el PDF indica corte parcial. En sábado/domingo conserva el viernes recién transcurrido. Se utilizan días completos, como las pantallas contables, y los registros disponibles al generar; no se afirma que la semana ya haya sido cerrada contablemente.

Los encabezados muestran ambas fechas, usuario y fecha de generación. Cada comparativo presenta semana actual, anterior y variaciones. Porcentaje = `(actual - anterior) / abs(anterior) × 100`; una base anterior cero se indica como `Sin base`, sin porcentajes infinitos. Los renglones de compras y gastos del estado de resultados conservan signo negativo.

## Resultado comercial

Se consulta `v_commercial_market_events`, la misma vista que alimenta Resultado Comercial, con eventos de Menudeo, Compras Mayoreo y Ventas Mayoreo. La carga se limita a las fechas de ambos periodos, ordena por fecha/área/ID y pagina de 500 en 500. El cálculo excluye los días intermedios de fin de semana y flujos desconocidos.

Se comparan importes de compra/venta, saldo comercial (ventas menos compras), kg y cantidad de operaciones. Se incluyen todos los canales y materiales de la unión de ambas semanas, incluso los que solo aparecen en la anterior. Los precios ponderados se calculan por material como importe/kg; un flujo sin kg no recibe precio ni diferencia artificial.

Este saldo no aplica valuación de inventario ni costo de lo vendido. No se suma al resultado neto del segundo bloque.

## Estado de resultados

Reutiliza `ContabilidadIncomeStatementStore.loadSimplified` con rangos explícitos para ambas semanas, la misma lectura que la pantalla y tarjeta de Contabilidad. Conserva ventas de material, otras entradas, compra de material, utilidad bruta, gastos y utilidad neta.

Fuentes: `finanzas_bank_movements`, comprobantes actuales y legados de Bóveda y caja Menudeo. Conserva las exclusiones por categorías internas, reposiciones de fondo y la conciliación Banco-Bóveda por cheque que ya aplica el área. Se comparan gastos y otras entradas por rubro y fuente sin mezclar rubros homónimos de fuentes distintas. Los conceptos que desaparecen en la semana actual permanecen con su importe anterior.

La exportación pasa `migrateLegacyVouchers: false` y activa lectura estricta del legado. No escribe movimientos ni migra comprobantes. Un error de consulta interrumpe la exportación; no se sustituye por un resultado cero.

## Integridad de carga

Se completó la paginación en las lecturas estrictas compartidas de Bancos, comprobantes de Bóveda, sus líneas y líneas de caja Menudeo. Conservan orden con ID para evitar perder filas al paginar. Las pantallas existentes mantienen su comportamiento; la nueva opción estricta del legado se activa en este reporte.

No requiere migraciones de base de datos. Los permisos existentes siguen aplicándose.

## Validación

Pruebas de fechas, semanas parciales y fines de semana; cambio de año; totales comerciales y ponderación; bases cero/negativas; materiales y rubros solo anteriores; separación de fuentes; fechas incompatibles; PDF denso, vacío y parcial. Integración con respuestas de las fuentes existentes: exclusión de movimientos internos, conciliación de cheque, legado duplicado, páginas de más de 500 movimientos y líneas, fallo de cada fuente, despacho central y navegación desde el dashboard.

La validación usa datos simulados y revisión visual de PDF. No se consultaron datos productivos ni se desplegó la aplicación.

Resultado: 99 pruebas aprobadas de reportes, tarjeta contable, Supervisión y Finanzas, incluidas las 12 pruebas nuevas. Análisis estático sin incidencias y `git diff --check` limpio. Se renderizaron y revisaron las 12 páginas del ejemplo denso, las 3 del parcial y las 3 del vacío; fechas, totales y límites de página verificados.
