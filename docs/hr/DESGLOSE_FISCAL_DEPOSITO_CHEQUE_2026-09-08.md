# Fiscal por depósito y cheque

Actualización de presentación del 11 de septiembre: [Cheque dentro del Flujo a entregar](CHEQUE_FLUJO_ENTREGA_2026-09-11.md). La pantalla ahora agrupa los pagos por medio de entrega; el cheque conserva su origen fiscal. El comportamiento visual descrito abajo corresponde a la versión anterior.

Prenómina y Nómina muestran el total fiscal dominante y, dentro de la misma tarjeta, su distribución en Depósito y Cheque. Los importes corresponden al periodo completo, aunque se filtre la tabla. Se conserva el espacio de trabajo de las tablas en ventanas pequeñas.

La distribución automática toma `fiscal_payment_mode` de Personal. Se corrigió el caso de borradores antiguos con `check_amount=0` o nulo: ese valor por sí solo no es una excepción manual y permite aplicar la configuración del expediente. Se conserva una distribución manual explícita (incluso cero), un cheque positivo legado, y los importes de nóminas publicadas, periodos cerrados o recibos emitidos. El cheque sólo redistribuye el fiscal; no incrementa el flujo, el neto oficial ni el total a pagar.

La columna fiscal de ambos grids identifica Cheque · efectivo, Depósito o Depósito + cheque. El PDF del periodo usa la misma distribución y muestra Total fiscal, Depósito fiscal y Cheque fiscal. Su nota aclara que el cheque forma parte del fiscal y se cuenta una sola vez.

## Comprobación con datos existentes

Una consulta limitada confirmó que siguen configurados como cheque los 11 perfiles cotejados con NOMINA35.xlsx: 114, 217, 252, 285, 286, 287, 289, 290, 297, 298 y 299. Esta revisión no modificó perfiles, importaciones ni movimientos de nómina.

El PDF `nomina 34.pdf` proporcionado contiene sólo dos colaboradores: IDs 2 y 8, ambos fuera de la lista de cheque. Por eso muestra fiscal $4,410.80, depósito $4,410.80 y cheque $0.00. En la consulta del 8 de septiembre sólo existen esos dos borradores para los periodos 34 y 35; aún no hay borradores guardados del periodo 35. Los demás colaboradores aparecerán en Nómina y su reporte cuando se guarden sus borradores en prenómina.

## Validación

- 80 pruebas de RH aprobadas, incluyendo los cálculos y las interacciones existentes.
- Flujo probado desde Personal hasta el borrador guardado, la nómina publicada y el generador real de PDF: 11 cheques y un control por depósito con importes sintéticos. Se comprobaron las columnas del PDF extraído: fiscal $25,700.00 = depósito $1,500.00 + cheque $24,200.00; total $29,000.00, sin duplicación.
- Revisión visual del PDF de prueba y de ambas pantallas. Las pruebas de ventanas compactas conservan búsqueda, selección y paginación sin desbordamientos.
- Análisis Dart sin problemas en los archivos de esta modificación. El análisis de toda la carpeta RH señala siete advertencias de declaraciones no usadas en Dashboard, Permisos y Vacaciones, fuera de este cambio.

Archivos de auditoría y pruebas locales: `/private/tmp/dicsa_fiscal_report/`. El PDF de prueba contiene datos sintéticos y no representa una nómina real.

Después de recargar Flutter se verificó la tarjeta en la app abierta, periodo 35: depósito $120,983.60 + cheque $19,252.40 = fiscal $140,236.00. El total a pagar permaneció en $165,819.92, igual al mostrado antes de activar la nueva tarjeta.
