# Captura de conceptos del Excel en Prenómina 35

Se guardaron y verificaron 33 borradores del periodo **21–27 de agosto de 2026**: 32 colaboradores con conceptos en `NOMINA35.xlsx`, más el ajuste RH de Javier Martínez Barrera. La carga se realizó por ID y nombre coincidentes en `Hoja1`, filas 11–83. Se conservaron las celdas vacías como ausencia de instrucción, sin borrar otros importes.

| Origen | Campo del detalle | Total capturado |
| --- | --- | ---: |
| V · Vacaciones en efectivo | Vacaciones en Flujo | $1,687.08 |
| X · Apoyo transporte | Transporte | $600.00 |
| Z · Bonos y horas extra | Horas extra + Bonos | $21,180.00 |
| AB · Descuento INFONAVIT | Descuento INFONAVIT en Flujo | $276.36 |
| AD · Descuento préstamo | Préstamo | $1,250.00 |
| Instrucción expresa del usuario | Ajuste RH de Javier | $315.08 |

Se mantuvieron las horas extra calculadas hasta el límite de Z y se capturó la diferencia en Bonos, conforme a la respuesta del usuario. En los 28 colaboradores con Z numérica, el desglose quedó en **$500 de horas extra y $20,680 de bonos**. Maricruz García tenía $34 calculados frente a $30 en el archivo: se monetizaron $30. No se modificaron minutos ni asistencia. Gabriel Rodríguez conserva sus $163 de horas extra porque Z está vacía en su fila y no se autorizó borrarlos; por ello, las horas extra monetizadas de toda la prenómina suman $663.

El ajuste de Javier quedó en Ajuste RH, separado de su salario contractual y del neto CONTPAQ: fiscal **$1,890.20**, flujo con ajuste **$3,009.80**, total **$4,900.00**. El Excel tiene $3,009.76 de efectivo; la diferencia de cuatro centavos obedece a la instrucción expresa de cerrar en $4,900.

El registro publicado de Rebeca no se modificó: fiscal, flujo y total continúan en **$0**. No se publicaron borradores, cerraron periodos ni liquidaron eventos.

## Verificación después de guardar

Se volvieron a consultar los registros persistidos y se ejecutó la proyección real de Prenómina, incluyendo guardar y reabrir. Los 33 borradores conservaron los conceptos esperados. El registro previo permaneció idéntico y ningún colaborador cambió su importe fiscal ni su distribución depósito/cheque.

| Concepto de la app | Importe posterior |
| --- | ---: |
| Fiscal en depósito | $125,066.00 |
| Fiscal en cheque | $23,659.80 |
| Total fiscal | $148,725.80 |
| Total calculado de Prenómina | $196,415.24 |
| Efectivo a entregar en sobres | $72,049.24 |

El total fiscal sigue $27.64 por debajo del Excel. Su diferencia previa corresponde a Rebeca (+$2,205.20 en el Excel), Dania (−$2,177.60 en el Excel) y Jesús Alejandro (+$0.04 en el Excel).

## Pendientes de conciliación

La coincidencia de estas cinco columnas no implica que el total del archivo esté conciliado. No se cambiaron salarios ni otros conceptos para forzar esa coincidencia.

- El Excel conserva 21 totales de efectivo vacíos. Varias de esas filas contienen bonos y otros importes positivos, que esta carga sí incorpora según lo solicitado. Por ejemplo, Emilio José Sandoval tiene $1,000 en bonos y total de efectivo vacío; José de Jesús Morales tiene $2,300 en bonos, $100 de transporte y total vacío. No se interpretó ese total vacío como autorización para descartar conceptos expresamente solicitados.
- Miguel Ángel Abundis tiene préstamo de $600 sin flujo disponible; Cruz Ángel Ramírez tiene préstamo de $100 sin flujo. Se registraron ambos descuentos en borrador. El cálculo muestra flujo negativo de $700 en conjunto, aunque el sobre se limita a cero. Esto explica que depósito más sobres exceda en $700 el total calculado. Debe resolverse la forma de cobro antes del cierre, sin cambiar automáticamente el neto CONTPAQ.
- Persisten diferencias de sueldo en efectivo, fuera de las columnas autorizadas: José Jesús Cienega tiene $3,339.84 en U frente a $2,394.72 de flujo en Personal; Ramón Fernando Miranda tiene U vacío frente a $694.72 de flujo. Se cargaron sus bonos y vacaciones solicitados sin modificar dichos salarios.
- Dania aparece con $2,260 de efectivo y sin fiscal en el Excel; la app conserva $2,177.60 de CONTPAQ y $94.80 de flujo. Requiere revisar su distribución por separado.
- El total de sobres actual es $72,049.24 frente a $59,208.48 en AE84: diferencia **$12,840.76**. Esta comparación incluye las omisiones de totales y diferencias anteriores; no es una diferencia fiscal nueva.

La evidencia de carga, relación de celdas y los 33 registros guardados están en `backups/hr_prenomina35_excel_2026-09-08/`. No contiene credenciales. La fuente original no se modificó.
